#!/usr/bin/env python3

# Python includes.
import argparse
import grp
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
    sys.exit("\nError: Please run this script as root.\n")

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
CPUCORES=multiprocessing.cpu_count()

# Ensure that certain commands exist.
cmdcheck = ["VBoxManage", "ssh", "sshpass"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

# Get arguments
parser = argparse.ArgumentParser(description='Create and run a Test VM.')
parser.add_argument("-n", "--noprompt",help='Do not prompt to continue.', action="store_true")
parser.add_argument("-d", "--desktop", type=int, help='Desktop Environment', default="0")
parser.add_argument("-b", "--displaymanager", type=int, help='Display Manager (if able to set)', default="0")
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
parser.add_argument("--memory", help="Memory for VM", default="2048")
parser.add_argument("--efi", help="Use EFI", action="store_true")
parser.add_argument("--vmbootstrap", help="Override bootstrap options.")
parser.add_argument("--vmprovision", help="Override provision options.")

# Save arguments.
args = parser.parse_args()

# Variables most likely to change.
vmpath = os.path.abspath(args.vmpath)
print("Path to VM Files is {0}".format(vmpath))
isopath = os.path.abspath(args.iso)
print("Path to LiveCD/ISO is {0}".format(isopath))
print("OS Type is {0}".format(args.ostype))
print("Desktop Environment is {0}".format(args.desktop))
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
else:
    grubnumber = 2

# Determine VM Name
if args.ostype == 1:
    vmname = "ArchTest"
    vboxosid = "ArchLinux_64"
    vmbootstrapscript = "BArchChroot.sh"
    vmbootstrap_defopts = '''-p /mnt -v "{0}"'''.format(args.vmpass)
    vmprovisionscript = "MArch.sh"
    vmprovision_defopts = "-e 3 -m 3"
elif args.ostype == 2:
    vmname = "DebianTest"
    vboxosid = "Debian_64"
    vmbootstrapscript = "BDeb_chroot.sh"
    vmbootstrap_defopts = '''-a amd64 -b 1 -p /mnt -v "{0}"'''.format(args.vmpass)
    vmprovisionscript = "MDebUbu.sh"
    vmprovision_defopts = "-e 3"
elif args.ostype == 3:
    vmname = "DebianTest"
    vboxosid = "Debian_64"
    vmbootstrapscript = "BDeb_chroot.sh"
    vmbootstrap_defopts = '''-a amd64 -b 2 -p /mnt -v "{0}"'''.format(args.vmpass)
    vmprovisionscript = "MDebUbu.sh"
    vmprovision_defopts = "-e 2"
elif args.ostype == 4:
    vmname = "UbuntuTest"
    vboxosid = "Ubuntu_64"
    vmbootstrapscript = "BDeb_chroot.sh"
    vmbootstrap_defopts = '''-a amd64 -b 3 -p /mnt -v "{0}"'''.format(args.vmpass)
    vmprovisionscript = "MDebUbu.sh"
    vmprovision_defopts = "-e 3"
elif args.ostype == 5:
    vmname = "FedoraTest"
    vboxosid = "Fedora_64"
    vmbootstrapscript = "BFedora.py"
    vmbootstrap_defopts = "-q '{0}' /mnt".format(args.vmpass)
    vmprovisionscript = "MArch.sh"
    vmprovision_defopts = ""
# Override bootstrap opts if provided.
if args.vmbootstrap is "None":
    vmboostrap_opts = vmbootstrap_defopts
else:
    vmbootstrap_opts = args.vmbootstrap
# Override provision opts if provided.
if args.vmprovision is None:
    vmprovision_opts = vmprovision_defopts
else:
    vmprovision_opts = args.vmprovision

# Variables less likely to change.
fullpathtovdi=vmpath+"/"+vmname+"/"+vmname+".vdi"
print("Path to VDI: {0}".format(fullpathtovdi))
vdisize="32768"
storagecontroller="SATA Controller"
localsshport=64321

if not os.path.isdir(vmpath) or not os.path.isfile(isopath):
    sys.exit("\nError, ensure {0} is a folder, and {1} is a file.".format(vmpath, isopath))

if args.noprompt == False:
    input("Press Enter to continue.")

### Functions ###
def sshwait(SSHUSER, SSHPASS, SSHPORT):
    print("Waiting for VM to boot.")
    time.sleep(15)
    sshwaitcmd = 'sshpass -p "{1}" ssh -q "{0}"@127.0.0.1 -p {3} "echo Connected"'.format(SSHUSER, SSHPASS, SSHPORT)
    status = subprocess.run(sshwaitcmd, shell=True)
    while status.returncode is not 0:
        print("SSH status was {0}, waiting.".format(status.returncode))
        time.sleep(5)
        status = subprocess.run(sshwaitcmd, shell=True)
    return

def shutdownwait():
    print("Waiting for shutdown...")
    time.sleep(10)
    shutdownwaitcmd = 'VBoxManage list runningvms | grep -i "{0}"'.format(vmname)
    status = subprocess.run(shutdownwaitcmd, shell=True)
    while status.returncode is not 0:
        print("Shutdown wait status was {0}, waiting.".format(status.returncode))
        time.sleep(10)
        status = subprocess.run(shutdownwaitcmd, shell=True)
    return

### Scripts ###

# Compose DELETESCRIPT
DELETESCRIPT="""
#!/bin/bash
VBoxManage storageattach "{0}" --storagectl "{1}" --port 0 --device 0 --type hdd --medium none
VBoxManage closemedium "{2}" --delete
if VBoxManage list vms | grep -i "{2}"; then
  VBoxManage unregistervm "{2}" --delete
fi
""".format(vmname, storagecontroller, fullpathtovdi)

# Compose CREATESCRIPT
CREATESCRIPT="""
#!/bin/bash

# Create the new VM
VBoxManage createvm --name "{vmname}" --register
VBoxManage modifyvm "{vmname}" --ostype "{vboxosid}" --ioapic on --rtcuseutc on --pae off
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

""".format(vmname=vmname, vboxosid=vboxosid, memory=args.memory, cpus=CPUCORES, fullpathtovdi=fullpathtovdi, vdisize=vdisize, isopath=isopath, storagecontroller=storagecontroller, sshport=localsshport)

# Compose STARTVM
STARTVM='VBoxManage startvm "{0}"'.format(vmname)

# Compose BOOTSTRAPCMD
BOOTSTRAPCMD="""
#!/bin/bash
sshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "cd /CustomScripts/; git pull"
""".format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport)
if args.efi == True:
    BOOTSTRAPCMD += '\nsshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "/CustomScripts/ZSlimDrive.py -g -n"'.format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport)
else:
    BOOTSTRAPCMD += '\nsshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "/CustomScripts/ZSlimDrive.py -n"'.format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport)
BOOTSTRAPCMD += '\nsshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "/CustomScripts/{script} -n -c {vmname} -u {username} -f \\"{fullname}\\" -g {grubnumber} {extraoptions}"'.format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport, vmname=vmname, username=args.vmuser, fullname=args.fullname, grubnumber=grubnumber, script=vmbootstrapscript, extraoptions=vmbootstrap_opts)
BOOTSTRAPCMD += """
sshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "mkdir -p /mnt/root/.ssh/; echo '{sshkey}' >> /mnt/root/.ssh/authorized_keys"
sshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "poweroff"
""".format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport, sshkey=rootsshkey)


# Compose PROVISIONCMD
PROVISIONCMD="""
#!/bin/bash
sshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "cd /CustomScripts/; git pull"
""".format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport)
if args.efi == True:
    PROVISIONCMD += 'sshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "/CustomScripts/ZSlimDrive.py -g -n"'.format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport)
else:
    PROVISIONCMD += 'sshpass -p "{sshpassword}" ssh 127.0.0.1 -p {sshport} -l {sshuser} "/CustomScripts/ZSlimDrive.py -n"'.format(sshpassword=args.livesshpass, sshuser=args.livesshuser, sshport=localsshport)

### Begin Code ###

if args.keep != True:
    # Delete old vm.
    if os.path.isfile(fullpathtovdi):
        print("Deleting old VM.")
        print(DELETESCRIPT)
        # subprocess.run(DELETESCRIPT, shell=True)

    # Create new VM.
    print("Creating VM.")
    print(CREATESCRIPT)
    # subprocess.run(CREATESCRIPT, shell=True)

    # Start VM
    # subprocess.run(STARTVM, shell=True, check=True)
    # sshwait(livesshuser, livesshpass, localsshport)

    # Bootstrap VM
    print(BOOTSTRAPCMD)
    # subprocess.run(BOOTSTRAPCMD, shell=True)

# Detach the iso
# time.sleep(2)
# subprocess.run('VBoxManage storageattach "{0}" --storagectl "{storagecontroller}" --port 1 --device 0 --type dvddrive --medium none'.format(vmname, storagecontroller), shell=True)

# Start VM
# subprocess.run(STARTVM, shell=True, check=True)
# sshwait(livesshuser, livesshpass, localsshport)

# Provision VM
print(PROVISIONCMD)
# subprocess.run(PROVISIONCMD, shell=True)
