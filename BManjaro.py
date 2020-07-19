#!/usr/bin/env python3
"""Install Manjaro from an Arch ISO. Specifically for use with packer."""

# Python includes.
import argparse
import os
import sys
import subprocess
import shutil
import stat
# Custom includes
import CFunc

print("Running {0}".format(__file__))
# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Debian/Ubuntu into a folder/chroot.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-c", "--hostname", help='Hostname', default="ManjaroTest")
parser.add_argument("-u", "--username", help='Username', default="user")
parser.add_argument("-f", "--fullname", help='Full Name', default="User Name")
parser.add_argument("-q", "--password", help='Password', default="asdf")
parser.add_argument("-i", "--grubpartition", help='Grub Custom Parition (if autodetection isnt working, i.e. /dev/sdb)', default=None)
parser.add_argument("installpath", help='Path of Installation')

# Save arguments.
args = parser.parse_args()
print("Hostname:", args.hostname)
print("Username:", args.username)
print("Full Name:", args.fullname)
# Get absolute path of the given path.
absinstallpath = os.path.realpath(args.installpath)
print("Path of Installation:", absinstallpath)
DEVPART = subprocess.run('sh -c df -m | grep " \+{0}$" | grep -Eo "/dev/[a-z]d[a-z]"'.format(absinstallpath), shell=True, check=True, stdout=subprocess.PIPE, universal_newlines=True)
grubautopart = format(DEVPART.stdout.strip())
print("Autodetect grub partition:", grubautopart)
if args.grubpartition is not None and stat.S_ISBLK(os.stat(args.grubpartition).st_mode) is True:
    grubpart = args.grubpartition
else:
    grubpart = grubautopart
print("Grub partition to be used:", grubpart)

# Exit if not root.
CFunc.is_root(True)

if args.noprompt is False:
    input("Press Enter to continue.")

# Grab the Manjaro pacman.conf
subprocess.run("wget https://gitlab.manjaro.org/packages/core/pacman/-/raw/master/pacman.conf.x86_64?inline=false -O /etc/pacman.conf", shell=True, check=True)
# Trust all packages
subprocess.run("sed -i 's/^SigLevel\s*=.*/SigLevel = Never/g' /etc/pacman.conf", shell=True, check=True)
# Add a Manjaro mirror
subprocess.run("echo 'Server = http://www.gtlib.gatech.edu/pub/manjaro/stable/$repo/$arch' > /etc/pacman.d/mirrorlist", shell=True, check=True)
# Install the manjaro keyring
subprocess.run("pacman -Syy manjaro-keyring archlinux-keyring")
# Run pacstrap
subprocess.run("pacstrap -G -C /pacman-aarch64.conf {0} base manjaro-system manjaro-release manjaro-keyring systemd systemd-libs linux56".format(absinstallpath), shell=True, check=True)
