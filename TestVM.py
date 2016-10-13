#!/usr/bin/env python3

# Python includes.
import argparse
import grp
import ipaddress
import multiprocessing
import os
import pwd
import shutil
import subprocess
import sys
import time

print("Running {0}".format(__file__))

# Exit if root.
if os.geteuid() == 0:
    sys.exit("\nError: Please run this script as a normal (non root) user.\n")

# Get non-root user information.
if os.getenv("SUDO_USER") != None and os.getenv("SUDO_USER") != "root":
    USERNAMEVAR=os.getenv("SUDO_USER")
elif os.getenv("USER") != "root":
    USERNAMEVAR=os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR=pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP=grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
USERHOME=os.path.expanduser("~")
CPUCORES=multiprocessing.cpu_count() if multiprocessing.cpu_count() <= 4 else 4

# Ensure that certain commands exist.
cmdcheck = ["VBoxManage", "ssh", "sshpass"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

# Get arguments
parser = argparse.ArgumentParser(description='Create and run a Test VM.')
parser.add_argument("-n", "--noprompt",help='Do not prompt to continue.', action="store_true")
parser.add_argument("-a", "--ostype", type=int, help="OS type (1=Arch, 2=Debian Unstable, 3=Debian Stable, 4=Ubuntu, 5=Fedora)", default="1")
parser.add_argument("-f", "--fullname", help="Full Name", default="User Name")
parser.add_argument("-i", "--iso", help="Path to live cd", required=True)
parser.add_argument("-p", "--vmpath", help="Path of Virtual Machine folders", required=True)
parser.add_argument("-v", "--rootsshkey", help="Root SSH Key")
parser.add_argument("-w", "--livesshuser", help="Live SSH Username", default="root")
parser.add_argument("-x", "--livesshpass", help="Live SSH Password", default="asdf")
parser.add_argument("-y", "--vmuser", help="VM Username", default="user")
parser.add_argument("-z", "--vmpass", help="VM Password", default="asdf")
parser.add_argument("-k", "--keep", help="Keep (do not delete) VM, and re-run desktop script.", action="store_true")
parser.add_argument("-q", "--qemu", help="Use QEMU/KVM instead of VirtualBox.", action="store_true")
parser.add_argument("--memory", help="Memory for VM", default="2048")
parser.add_argument("--efi", help="Use EFI", action="store_true")
parser.add_argument("--vmbootstrap", help="Override bootstrap options.")
parser.add_argument("--vmprovision", help="Override provision options.")
parser.add_argument("--driveopts", help="Add drive creation options.")

# Save arguments.
args = parser.parse_args()

# Variables most likely to change.
vmpath = os.path.abspath(args.vmpath)
print("Path to VM Files is {0}".format(vmpath))
isopath = os.path.abspath(args.iso)
print("Path to LiveCD/ISO is {0}".format(isopath))
print("OS Type is {0}".format(args.ostype))
print("VM Memory is {0}".format(args.memory))
print("Live SSH user is {0}".format(args.livesshuser))
print("VM User is {0}".format(args.vmuser))
# Detect root ssh key.
if args.rootsshkey != None:
    rootsshkey = args.rootsshkey
elif os.path.isfile(USERHOME+"/.ssh/id_ed25519.pub") == True:
    with open(USERHOME+"/.ssh/id_ed25519.pub", 'r') as sshfile:
        rootsshkey=sshfile.read().replace('\n', '')
elif os.path.isfile(USERHOME+"/.ssh/id_rsa.pub") == True:
    with open(USERHOME+"/.ssh/id_rsa.pub", 'r') as sshfile:
        rootsshkey=sshfile.read().replace('\n', '')
else:
    sys.exit("\nError, ssh key not detect. Please specify one.")
print("SSH Key is \"{0}\"".format(rootsshkey))
# Set grub number
if args.efi == True:
    grubnumber = 3
    zslimopts = "-g "
    vboxefiselect = "efi"
else:
    grubnumber = 2
    zslimopts = " "
    vboxefiselect = "bios"

# Determine VM Name
if args.ostype == 1:
    vmname = "ArchTest"
    vboxosid = "ArchLinux_64"
    vmbootstrapscript = "BArchChroot.sh"
    vmbootstrap_defopts = '-p /mnt -v \\"{0}\\"'.format(args.vmpass)
    vmprovisionscript = "MArch.sh"
    vmprovision_defopts = "-e 3 -m 3"
    kvm_variant = "fedora24"
elif args.ostype == 2:
    vmname = "DebianTest"
    vboxosid = "Debian_64"
    vmbootstrapscript = "BDebian.py"
    vmbootstrap_defopts = '-t debian -r unstable -q \\"{0}\\" /mnt'.format(args.vmpass)
    vmprovisionscript = "MDebUbu.sh"
    vmprovision_defopts = "-e 2"
    kvm_variant = "debian8"
elif args.ostype == 3:
    vmname = "DebianTest"
    vboxosid = "Debian_64"
    vmbootstrapscript = "BDebian.py"
    vmbootstrap_defopts = '-t debian -r jessie -q \\"{0}\\" /mnt'.format(args.vmpass)
    vmprovisionscript = "MDebUbu.sh"
    vmprovision_defopts = "-e 3"
    kvm_variant = "debian8"
elif args.ostype == 4:
    vmname = "UbuntuTest"
    vboxosid = "Ubuntu_64"
    vmbootstrapscript = "BDebian.py"
    vmbootstrap_defopts = '-t ubuntu -r xenial -q \\"{0}\\" /mnt'.format(args.vmpass)
    vmprovisionscript = "MDebUbu.sh"
    vmprovision_defopts = "-e 3"
    kvm_variant = "ubuntu16.04"
elif args.ostype == 5:
    vmname = "FedoraTest"
    vboxosid = "Fedora_64"
    vmbootstrapscript = "BFedora.py"
    vmbootstrap_defopts = '-q \\"{0}\\" /mnt'.format(args.vmpass)
    vmprovisionscript = "MFedora.sh"
    vmprovision_defopts = " "
    kvm_variant = "fedora24"
# Override bootstrap opts if provided.
if args.vmbootstrap is None:
    vmbootstrap_opts = vmbootstrap_defopts
else:
    vmbootstrap_opts = args.vmbootstrap
print("VM Bootstrap Options:", vmbootstrap_opts)
# Override provision opts if provided.
if args.vmprovision is None:
    vmprovision_opts = vmprovision_defopts
else:
    vmprovision_opts = args.vmprovision
print("VM Provision Options:", vmprovision_opts)
# Add drive Options
if args.driveopts is not None:
    zslimopts += args.driveopts
print("Drive Options:", zslimopts)

# Variables less likely to change.
if args.qemu is True:
    fullpathtovdi=vmpath+"/"+vmname+".qcow2"
    sship = None
    localsshport=22
else:
    fullpathtovdi=vmpath+"/"+vmname+"/"+vmname+".vdi"
    sship = "127.0.0.1"
    localsshport=64321
print("Path to Image: {0}".format(fullpathtovdi))
vdisize="32768"
storagecontroller="SATA Controller"

if not os.path.isdir(vmpath) or not os.path.isfile(isopath):
    sys.exit("\nError, ensure {0} is a folder, and {1} is a file.".format(vmpath, isopath))

if args.noprompt == False:
    input("Press Enter to continue.")

### Functions ###
def startvm(VMNAME):
    if args.qemu is True:
        checkvmcmd = 'virsh --connect qemu:///system -q list | grep -i "{0}"'.format(vmname)
        startvmcmd = "virsh --connect qemu:///system start {vmname}".format(vmname=vmname)
    else:
        checkvmcmd = 'VBoxManage list runningvms | grep -i "{0}"'.format(VMNAME)
        startvmcmd = 'VBoxManage startvm "{0}"'.format(VMNAME)
    subprocess.run(startvmcmd, shell=True)
    time.sleep(2)
    status = subprocess.run(checkvmcmd, shell=True)
    while status.returncode is not 0:
        time.sleep(2)
        subprocess.run(startvmcmd, shell=True)
    return

def sshwait(SSHIP, SSHUSER, SSHPASS, SSHPORT):
    if args.qemu is False:
        print("Waiting for VM to boot.")
        time.sleep(15)
    sshwaitcmd = 'sshpass -p "{SSHPASS}" ssh -q "{SSHUSER}"@{SSHIP} -p {SSHPORT} "echo Connected"'.format(SSHIP=SSHIP, SSHUSER=SSHUSER, SSHPASS=SSHPASS, SSHPORT=SSHPORT)
    status = subprocess.run(sshwaitcmd, shell=True)
    while status.returncode is not 0:
        print("SSH status was {0}, waiting.".format(status.returncode))
        time.sleep(5)
        status = subprocess.run(sshwaitcmd, shell=True)
    return

def shutdownwait():
    print("Waiting for shutdown...")
    time.sleep(3)
    if args.qemu is True:
        shutdownwaitcmd = 'virsh --connect qemu:///system -q list | grep -i "{0}"'.format(vmname)
    else:
        shutdownwaitcmd = 'VBoxManage list runningvms | grep -i "{0}"'.format(vmname)
    status = subprocess.run(shutdownwaitcmd, shell=True)
    # If a vm was detected (status was 0), wait for the vm to disappear.
    while status.returncode is 0:
        print("Shutdown wait status was {0}, waiting.".format(status.returncode))
        time.sleep(10)
        status = subprocess.run(shutdownwaitcmd, shell=True)
    return

def kvm_getip(VMNAME):
    print("Getting KVM IP address...")
    kvmipcmd="virsh --connect qemu:///system -q domifaddr {0} | awk '{{ print $4 }}'".format(VMNAME)
    ip = None
    while ip is None:
        # Get the ip from the command.
        ip_cmd = subprocess.run(kvmipcmd, shell=True, stdout=subprocess.PIPE, universal_newlines=True)
        # Strip the newlines.
        ip = format(ip_cmd.stdout.strip())
        # Keep only the IP, remove the subnet mask.
        ip = ip.split("/", 1)[0]
        # Check to see if it is a valid IP address.
        try:
           ipaddress.ip_address(ip)
           print('{0} is a correct IP address.'.format(ip))
        except:
           print('Address/Netmask is invalid: {0}'.format(ip))
           ip = None
        time.sleep(3)
    return ip

def vm_bootstrap():
    # Compose BOOTSTRAPCMD
    BOOTSTRAPCMD="""#!/bin/bash
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "cd /CustomScripts/; git pull"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "/CustomScripts/ZSlimDrive.py -n {zslimopts}"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "/CustomScripts/{vmbootstrapscript} -n -c {vmname} -u {username} -f \\"{fullname}\\" -g {grubnumber} {vmbootstrap_opts}"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "mkdir -p /mnt/root/.ssh/; echo '{sshkey}' >> /mnt/root/.ssh/authorized_keys"
sshpass -p "{sshpassword}" ssh {sship} -p {sshport} -l {sshuser} "poweroff"
    """.format(sship=sship, sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport, vmname=vmname, username=args.vmuser, fullname=args.fullname, grubnumber=grubnumber, vmbootstrapscript=vmbootstrapscript, vmbootstrap_opts=vmbootstrap_opts, zslimopts=zslimopts, sshkey=rootsshkey)
    subprocess.run(BOOTSTRAPCMD, shell=True)
    return

def vm_provision():
    # Compose PROVISIONCMD
    PROVISIONCMD="""
    #!/bin/bash
    ssh {sship} -p {sshport} -l root "cd /opt/CustomScripts/; git pull"
    ssh {sship} -p {sshport} -l root "/opt/CustomScripts/{vmprovisionscript} -n {vmprovision_opts} -s {password}"
    ssh {sship} -p {sshport} -l root "reboot"
    """.format(sship=sship, sshport=localsshport, password=args.vmpass, vmprovisionscript=vmprovisionscript, vmprovision_opts=vmprovision_opts)
    subprocess.run(PROVISIONCMD, shell=True)
    return

### Scripts ###

# Compose DELETESCRIPT
DELETESCRIPT="""#!/bin/bash
VBoxManage storageattach "{0}" --storagectl "{1}" --port 0 --device 0 --type hdd --medium none
VBoxManage closemedium "{2}" --delete
if VBoxManage list vms | grep -i "{0}"; then
  VBoxManage unregistervm "{0}" --delete
fi
""".format(vmname, storagecontroller, fullpathtovdi)

DELETESCRIPT_KVM="""#!/bin/bash
virsh --connect qemu:///system destroy {0}
virsh --connect qemu:///system undefine {0}
""".format(vmname)

# Compose CREATESCRIPT
CREATESCRIPT_VBOX="""#!/bin/bash
# Create the new VM
VBoxManage createvm --name "{vmname}" --register
VBoxManage modifyvm "{vmname}" --ostype "{vboxosid}" --ioapic on --rtcuseutc on --pae off  --firmware {vboxefiselect}
VBoxManage modifyvm "{vmname}" --memory "{memory}"
VBoxManage modifyvm "{vmname}" --vram 32
VBoxManage modifyvm "{vmname}" --mouse usbtablet
VBoxManage modifyvm "{vmname}" --cpus "{cpus}"
VBoxManage modifyvm "{vmname}" --clipboard bidirectional --draganddrop bidirectional --usbehci on
# Storage settings
VBoxManage createhd --filename "{fullpathtovdi}" --size "{vdisize}"
VBoxManage storagectl "{vmname}" --name "{storagecontroller}" --add sata --portcount 4
VBoxManage storageattach "{vmname}" --storagectl "{storagecontroller}" --port 0 --device 0 --type hdd --medium "{fullpathtovdi}"
VBoxManage storageattach "{vmname}" --storagectl "{storagecontroller}" --port 1 --device 0 --type dvddrive --medium "{isopath}"
VBoxManage modifyvm "{vmname}" --boot1 dvd --boot2 disk
# Network settings
VBoxManage modifyvm "{vmname}" --nic1 nat --nictype1 82540EM --cableconnected1 on
VBoxManage modifyvm "{vmname}" --natpf1 "ssh,tcp,127.0.0.1,{sshport},,22"
""".format(vmname=vmname, vboxosid=vboxosid, memory=args.memory, cpus=CPUCORES, fullpathtovdi=fullpathtovdi, vdisize=vdisize, isopath=isopath, storagecontroller=storagecontroller, sshport=localsshport, vboxefiselect=vboxefiselect)
CREATESCRIPT_KVM="""#!/bin/bash
qemu-img create -f qcow2 -o compat=1.1,lazy_refcounts=on {fullpathtovdi} {vdisize}M
virt-install --connect qemu:///system --name={vmname} --disk path={fullpathtovdi},bus=virtio --graphics spice --vcpu={cpus} --ram={memory} --cdrom={isopath}  --network bridge=virbr0,model=virtio --network network=vnet5,model=virtio --os-type=linux --os-variant={kvm_variant} --noautoconsole --video=virtio
""".format(vmname=vmname, memory=args.memory, cpus=CPUCORES, fullpathtovdi=fullpathtovdi, vdisize=vdisize, isopath=isopath, sshport=localsshport, kvm_variant=kvm_variant)

### Begin Code ###

# Virtualbox code
if args.qemu is True:
    # Run this if we are destroying (not keeping) the VM.
    if args.keep != True:
        # Delete old vm.
        if os.path.isfile(fullpathtovdi):
            print("\nDeleting old VM.")
            subprocess.run(DELETESCRIPT_KVM, shell=True)
            os.remove(fullpathtovdi)

        # Create new VM.
        print("\nCreating VM.")
        subprocess.run(CREATESCRIPT_KVM, shell=True)

        # Get VM IP
        sship = kvm_getip(vmname)
        sshwait(sship, args.livesshuser, args.livesshpass, localsshport)

        # Bootstrap VM
        vm_bootstrap()

        # Shutdown VM
        subprocess.run("virsh --connect qemu:///system shutdown {vmname}".format(vmname=vmname), shell=True)
        shutdownwait()

    # # Detach the iso
    # time.sleep(2)
    # subprocess.run('VBoxManage storageattach "{0}" --storagectl "{1}" --port 1 --device 0 --type dvddrive --medium emptydrive'.format(vmname, storagecontroller), shell=True)

    # Start VM
    startvm()

    # Get VM IP
    sship = kvm_getip(vmname)
    sshwait(sship, args.livesshuser, args.livesshpass, localsshport)

    # Provision VM
    vm_provision()

else:
    # Run this if we are destroying (not keeping) the VM.
    if args.keep != True:
        # Delete old vm.
        if os.path.isfile(fullpathtovdi):
            print("\nDeleting old VM.")
            # print(DELETESCRIPT)
            subprocess.run(DELETESCRIPT, shell=True)

        # Create new VM.
        print("\nCreating VM.")
        # print(CREATESCRIPT)
        subprocess.run(CREATESCRIPT_VBOX, shell=True)

        # Start VM
        startvm(vmname)
        sshwait(sship, args.livesshuser, args.livesshpass, localsshport)

        # Bootstrap VM
        vm_bootstrap()

    # Detach the iso
    shutdownwait()
    time.sleep(2)
    subprocess.run('VBoxManage storageattach "{0}" --storagectl "{1}" --port 1 --device 0 --type dvddrive --medium emptydrive'.format(vmname, storagecontroller), shell=True)

    # Start VM
    startvm(vmname)
    sshwait(sship, args.vmuser, args.vmpass, localsshport)

    # Provision VM
    subprocess.run(PROVISIONCMD, shell=True)
