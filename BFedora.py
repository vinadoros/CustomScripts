#!/usr/bin/env python3

# Python includes.
import argparse
import os
import sys
import subprocess
import shutil

# Globals
SCRIPTDIR=sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Fedora into a folder/chroot.')
parser.add_argument("-n", "--noprompt",help='Do not prompt to continue.', action="store_true")
parser.add_argument("-c", "--hostname", dest="hostname", help='Hostname', default="FedoraTest")
parser.add_argument("-u", "--username", dest="username", help='Username', default="user")
parser.add_argument("-f", "--fullname", dest="fullname", help='Full Name', default="User Name")
parser.add_argument("-q", "--password", dest="password", help='Password', default="asdf")
parser.add_argument("-g", "--grub", type=int, dest="grubtype", help='Grub Install Number', default=1)
parser.add_argument("-t", "--type", dest="type", help='Type of release (fedora, centos, etc)', default="fedora")
parser.add_argument("-v", "--version", dest="version", help='Version of Release', default=24)
parser.add_argument("installpath", help='Path of Installation')

# Save arguments.
args = parser.parse_args()
print("Hostname:",args.hostname)
print("Username:",args.username)
print("Full Name:",args.fullname)
print("Grub Install Number:",args.grubtype)
print("Path of Installation:",args.installpath)
print("Type of release:",args.type)
print("Version of Release:",args.version)

# Exit if not root.
if not os.geteuid() == 0:
    sys.exit("\nError: Please run this script as root.\n")

if args.noprompt == False:
    input("Press Enter to continue.")

subprocess.run("dnf --releasever="+args.version+" --installroot="+args.installpath+" --assumeyes install kernel kernel-modules kernel-modules-extra @workstation-product @gnome-desktop @core @hardware-support @networkmanager-submodules @fonts @base-x grub2", shell=True, check=True)
subprocess.run("genfstab -U %s > %s/etc/fstab" % (args.installpath, args.installpath), shell=True, check=True)

# Copy resolv.conf into chroot
shutil.copy2("/etc/resolv.conf", args.installpath+"/etc/resolv.conf")

# Create and run setup script.
SETUPSCRIPT_PATH = args.installpath+"/setupscript.sh"
SETUPSCRIPT_VAR = open(SETUPSCRIPT_PATH, mode='w')
SETUPSCRIPT_SCRIPT="""
#!/bin/bash

# Variables

PY_HOSTNAME="%s"
PY_USERNAME="%s"
PY_PASSWORD="%s"
PY_FULLNAME="%s"

echo "Running Fedora Setup Script"

# Install more packages
dnf install -y util-linux-user nano

# Unlocking root account
passwd -u root
chpasswd <<<"root:$PY_PASSWORD"
# Disable selinux
sed -i 's/SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
# Set hostname
hostnamectl set-hostname "$PY_HOSTNAME"
# Setup new user.
useradd -m -g users -G wheel -s /bin/bash $PY_USERNAME
chfn -f "$PY_FULLNAME" $PY_USERNAME
chpasswd <<<"$PY_USERNAME:$PY_PASSWORD"

# Install Grub
""" % (args.hostname, args.username, args.password, args.fullname)
SETUPSCRIPT_VAR.write(SETUPSCRIPT_SCRIPT)

# Install kernel, grub.
if 2 <= args.grubtype <= 4:
    SETUPSCRIPT_VAR.write('\ngrub2-mkconfig -o /boot/grub2/grub.cfg')

# Insert Grub section
SETUPSCRIPT_VAR.write('\necho "Grub Section"\n')
if args.grubtype == 2:
    # TODO: Fix devpart output below.
    # DEVPART = subprocess.run('sh -c df -m | grep " \+'+args.installpath+'$" | grep -Eo "/dev/[a-z]d[a-z]"', shell=True, stdout=subprocess.PIPE)
    SETUPSCRIPT_VAR.write('\ngrub2-install --target=i386-pc --recheck --debug /dev/sda')
elif args.grubtype == 3:
    SETUPSCRIPT_VAR.write('\ngrub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=fedora --recheck --debug')
elif args.grubtype == 4:
    print("Todo")

# Close and run the script.
SETUPSCRIPT_VAR.close()
os.chmod(SETUPSCRIPT_PATH, 0o777)
subprocess.run("arch-chroot "+args.installpath+" /setupscript.sh", shell=True)
# Remove after running
# os.remove(SETUPSCRIPT_PATH)
