#!/usr/bin/env python3
"""Install Manjaro from an Arch ISO. Specifically for use with packer."""

# Python includes.
import argparse
import os
import sys
import subprocess
import stat
# Custom includes
import CFunc
import MManjaro
import zch

print("Running {0}".format(__file__))
# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Debian/Ubuntu into a folder/chroot.')

parser.add_argument("-c", "--hostname", help='Hostname', default="ManjaroTest")
parser.add_argument("-f", "--fullname", help='Full Name', default="User Name")
parser.add_argument("-i", "--grubpartition", help='Grub Custom Parition (if autodetection isnt working, i.e. /dev/sdb)', default=None)
parser.add_argument("-l", "--linuxpkg", help='Linux package to install (default: %(default)s)', default="linux-lts")
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-q", "--password", help='Password', default="asdf")
parser.add_argument("-u", "--username", help='Username', default="user")
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
subprocess.run("curl -o /etc/pacman.conf https://gitlab.manjaro.org/packages/core/pacman/-/raw/master/pacman.conf.x86_64?inline=false", shell=True, check=True)
# Trust all packages
subprocess.run("sed -i 's/^SigLevel\s*=.*/SigLevel = Never/g' /etc/pacman.conf", shell=True, check=True)
# Add a Manjaro mirror
subprocess.run("echo 'Server = http://www.gtlib.gatech.edu/pub/manjaro/stable/$repo/$arch' > /etc/pacman.d/mirrorlist", shell=True, check=True)
# Install the manjaro keyring
subprocess.run("pacman -Syy --noconfirm manjaro-keyring archlinux-keyring", shell=True, check=True)
# Use the argument linuxpkg if set. Confirm this option is in the list.
if args.linuxpkg and any(args.linuxpkg == linuxopt for linuxopt in MManjaro.kernels_getlist()):
    linuxpkg = args.linuxpkg
else:
    # Get latest kernel if no argument given.
    linuxpkg = MManjaro.kernels_getlatest()
# Run pacstrap
subprocess.run("pacstrap -G {0} base manjaro-system manjaro-release systemd systemd-libs {1}".format(absinstallpath, linuxpkg), shell=True, check=True)
# Generate fstab
subprocess.run("genfstab -U {0} > {0}/etc/fstab".format(absinstallpath), shell=True, check=True)

# Mount chroot paths
zch.ChrootMountPaths(absinstallpath)
zch.ChrootRunCommand(absinstallpath, "pacman-key --init")
zch.ChrootRunCommand(absinstallpath, "pacman-key --populate archlinux manjaro")
zch.ChrootRunCommand(absinstallpath, "pacman -Syu --noconfirm --needed sudo nano which openssh rng-tools haveged networkmanager wpa_supplicant")
zch.ChrootRunCommand(absinstallpath, "systemctl enable sshd NetworkManager rngd")
# Allow wheel to run sudo commands
zch.ChrootRunCommand(absinstallpath, "sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers")
# Allow root login for ssh
zch.ChrootRunCommand(absinstallpath, "sed -i 's/PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config")
zch.ChrootRunCommand(absinstallpath, "sed -i '/^#PermitRootLogin.*/s/^#//g' /etc/ssh/sshd_config")
# Locale info
zch.ChrootRunCommand(absinstallpath, 'sed -i -e "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen')
zch.ChrootRunCommand(absinstallpath, 'echo "LANG=en_US.UTF-8" > /etc/locale.conf', run_quoted_with_bash=True)
zch.ChrootRunCommand(absinstallpath, 'echo "LANG=\"en_US.UTF-8\"" > /etc/default/locale', run_quoted_with_bash=True)
zch.ChrootRunCommand(absinstallpath, "locale-gen")
# Add normal user information
zch.ChrootRunCommand(absinstallpath, "useradd -m -g users -G wheel -s /bin/bash {0}".format(args.username))
zch.ChrootRunCommand(absinstallpath, 'chpasswd <<<"{0}:{1}"'.format(args.username, args.password))
zch.ChrootRunCommand(absinstallpath, 'chpasswd <<<"root:{0}"'.format(args.password))
zch.ChrootRunCommand(absinstallpath, 'chfn -f "{0}" {1}'.format(args.fullname, args.username))
# Add hostname
zch.ChrootRunCommand(absinstallpath, 'echo "{0}" > /etc/hostname'.format(args.hostname), run_quoted_with_bash=True)
# Install and run grub
zch.ChrootRunCommand(absinstallpath, "pacman -S --noconfirm --needed grub grub-theme-manjaro os-prober freetype2 mtools")
zch.ChrootRunCommand(absinstallpath, "grub-install --target=i386-pc --recheck {0}".format(grubpart))
zch.ChrootRunCommand(absinstallpath, "grub-mkconfig -o /boot/grub/grub.cfg")
# End and unmount chroot paths
zch.ChrootUnmountPaths(absinstallpath)
