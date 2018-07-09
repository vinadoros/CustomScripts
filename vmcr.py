#!/usr/bin/env python3
"""Create a virtual machine entry"""

# Python includes.
import argparse
import multiprocessing
import os
import random
import shutil
import string
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Exit if root.
CFunc.is_root(False)

# Get system and user information.
USERHOME = os.path.expanduser("~")
CPUCORES = multiprocessing.cpu_count() if multiprocessing.cpu_count() <= 4 else 4

# Get arguments
parser = argparse.ArgumentParser(description='Create a VM using packer.')
parser.add_argument("-n", "--vmname", help="Name of Virtual Machine")
parser.add_argument("-t", "--vmtype", type=int, help="Virtual Machine type (1=Virtualbox, 2=libvirt, 3=VMWare, 4=hyperv, 5=qemu)", default="1")
parser.add_argument("-a", "--ostype", type=int, help="OS type", default="1")
parser.add_argument("-f", "--fullname", help="Full Name", default="User Name")
parser.add_argument("-i", "--iso", help="Path to live cd")
parser.add_argument("-s", "--imgsize", type=int, help="Size of image", default=65536)
parser.add_argument("-j", "--harddiskimage", help="Existing Hard Disk image")
parser.add_argument("-p", "--vmpath", help="Path to create Virtual Machine in", required=True)
parser.add_argument("-y", "--vmuser", help="VM Username", default="user")
parser.add_argument("-z", "--vmpass", help="VM Password", default="asdf")
parser.add_argument("-x", "--sshkey", help="SSH authorizaiton key")
parser.add_argument("-m", "--memory", help="Memory for VM", default="4096")

# Save arguments.
args = parser.parse_args()

# Variables most likely to change.
vmpath = os.path.abspath(args.vmpath)
print("Path to Packer output is {0}".format(vmpath))
print("OS Type is {0}".format(args.ostype))
print("VM Memory is {0}".format(args.memory))
print("VM Hard Disk size is {0}".format(args.imgsize))
print("VM User is {0}".format(args.vmuser))


# Determine VM hypervisor
if args.vmtype == 1:
    hvname = "vbox"
    # cmdcheck = ["VBoxManage"]
elif args.vmtype == 2:
    hvname = "kvm"
elif args.vmtype == 3:
    hvname = "vmware"
elif args.vmtype == 4:
    hvname = "hyperv"

# Ensure that certain commands exist.
# for cmd in cmdcheck:
#     if not shutil.which(cmd):
#         sys.exit("\nError, ensure command {0} is installed.".format(cmd))

# Set OS options.
# KVM os options can be found by running "osinfo-query os"
if args.ostype == 1:
    vboxosid = "Ubuntu_64"
    kvm_os = "linux"
    kvm_variant = "debiantesting"
if args.ostype == 2:
    vboxosid = "Windows10_64"
    vmwareid = "windows9-64"
    kvm_os = "windows"
    kvm_variant = "win10"

# Override VM Name if provided
if args.vmname is not None:
    vmname = args.vmname
else:
    vmname = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
print("VM Name is {0}".format(vmname))

# Check iso and/or image
if args.iso is not None:
    isopath = os.path.abspath(args.iso)
    print("Path to ISO is {0}".format(isopath))
else:
    isopath = None
    print("No ISO specified.")
if args.harddiskimage is not None:
    hdimage = os.path.abspath(args.harddiskimage)
    print("Path to Hard Drive image is {0}".format(hdimage))
else:
    hdimage = None
    print("No hard drive image specified.")

input("Press Enter to continue.")

# Set up VM hypervisor settings
if args.vmtype == 1:
    # Set vbox machine folder path.
    subprocess.run('vboxmanage setproperty machinefolder "{0}"'.format(vmpath), shell=True, check=True)
    # Create host only adapter if it does not exist.
    if CFunc.is_windows():
        vbox_hostonlyif_name = "VirtualBox Host-Only Ethernet Adapter"
    else:
        vbox_hostonlyif_name = "vboxnet0"
    vbox_hostonlyifs = CFunc.subpout("vboxmanage list hostonlyifs")
    if vbox_hostonlyif_name not in vbox_hostonlyifs:
        print("Creating {0} hostonlyif.".format(vbox_hostonlyif_name))
        subprocess.run("vboxmanage hostonlyif create", shell=True, check=True)
        # Set DHCP active on created adapter
        subprocess.run('vboxmanage hostonlyif ipconfig "{0}" --ip 192.168.253.1'.format(vbox_hostonlyif_name), shell=True, check=True)
        subprocess.run('vboxmanage dhcpserver modify --ifname "{0}" --ip 192.168.253.1 --netmask 255.255.255.0 --lowerip 192.168.253.2 --upperip 192.168.253.253 --enable'.format(vbox_hostonlyif_name), shell=True, check=True)
elif args.vmtype == 4:
    # Create an external switch if it does not already exist. External switch is required for guests to get DHCP.
    # https://github.com/MattHodge/PackerTemplates#building-hyper-v-images
    hyperv_switch_name = "External VM Switch"
    hyperv_mainnetadapter_name = "Ethernet"
    hyperv_winadapters = CFunc.subpout('powershell -c "Get-NetAdapter -Name "*" | Format-List -Property "Name""')
    if hyperv_switch_name not in hyperv_winadapters:
        subprocess.run('''powershell -c "New-VMSwitch -name '{0}' -NetAdapterName '{1}' -AllowManagementOS $true"'''.format(hyperv_switch_name, hyperv_mainnetadapter_name), shell=True)

# Delete leftover VMs
if args.vmtype == 1:
    vboxvmlist = CFunc.subpout("VBoxManage list vms")
    if vmname in vboxvmlist:
        subprocess.run('VBoxManage unregistervm "{0}" --delete'.format(vmname), shell=True)

# Detect root ssh key.
if args.sshkey is not None:
    sshkey = args.rootsshkey
elif os.path.isfile(os.path.join(USERHOME, ".ssh", "id_ed25519.pub")) is True:
    with open(os.path.join(USERHOME, ".ssh", "id_ed25519.pub"), 'r') as sshfile:
        sshkey = sshfile.read().replace('\n', '')
elif os.path.isfile(os.path.join(USERHOME, ".ssh", "id_rsa.pub")) is True:
    with open(os.path.join(USERHOME, ".ssh", "id_rsa.pub"), 'r') as sshfile:
        sshkey = sshfile.read().replace('\n', '')
else:
    sshkey = " "
print("SSH Key is \"{0}\"".format(sshkey))

# Generate hashed password
# https://serverfault.com/questions/330069/how-to-create-an-sha-512-hashed-password-for-shadow#330072

if CFunc.is_windows() is True:
    from passlib import hash
    sha512_password = hash.sha512_crypt.encrypt(args.vmpass, rounds=5000)
else:
    import crypt
    sha512_password = crypt.crypt(args.vmpass, crypt.mksalt(crypt.METHOD_SHA512))

# Create Virtual Machine
if args.vmtype == 2:
    if args.ostype == 1:
        kvm_video = "virtio"
        kvm_diskinterface = "virtio"
        kvm_netdevice = "virtio"
    elif args.ostype == 2:
        kvm_video = "qxl"
        kvm_diskinterface = "ide"
        kvm_netdevice = "virtio"
    # virt-install manual: https://www.mankier.com/1/virt-install
    CREATESCRIPT_KVM = """virt-install --connect qemu:///system --name={vmname}  --graphics spice --vcpu={cpus} --ram={memory} --network bridge=virbr0,model={kvm_netdevice} --filesystem source=/,target=root,mode=mapped --os-type={kvm_os} --os-variant={kvm_variant} --import --noautoconsole --video={kvm_video} --channel unix,target_type=virtio,name=org.qemu.guest_agent.0""".format(vmname=vmname, memory=args.memory, cpus=CPUCORES, kvm_os=kvm_os, kvm_variant=kvm_variant, kvm_video=kvm_video, kvm_netdevice=kvm_netdevice)
    if hdimage is not None:
        CREATESCRIPT_KVM += " --disk path={fullpathtoimg}.qcow2,bus={kvm_diskinterface}".format(fullpathtoimg=hdimage, kvm_diskinterface=kvm_diskinterface)
    else:
        imgfullpath = os.path.join(vmpath, "{0}.qcow2".format(vmname))
        subprocess.run("qemu-img create -f qcow2 -o compat=1.1,lazy_refcounts=on {0} {1}M".format(imgfullpath, args.imgsize), shell=True)
        CREATESCRIPT_KVM += " --disk path={fullpathtoimg},bus={kvm_diskinterface}".format(fullpathtoimg=imgfullpath, kvm_diskinterface=kvm_diskinterface)
    if isopath is not None:
        CREATESCRIPT_KVM += " --disk={0},device=cdrom --boot cdrom,hd".format(isopath)
    print("KVM launch command: {0}".format(CREATESCRIPT_KVM))
    subprocess.run(CREATESCRIPT_KVM, shell=True)
