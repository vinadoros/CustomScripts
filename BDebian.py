#!/usr/bin/env python3

# Python includes.
import argparse
import os
import sys
import subprocess
import shutil
import stat

# Globals
SCRIPTDIR=sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Debian/Ubuntu into a folder/chroot.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-c", "--hostname", help='Hostname', default="DebianTest")
parser.add_argument("-u", "--username", help='Username', default="user")
parser.add_argument("-f", "--fullname", help='Full Name', default="User Name")
parser.add_argument("-q", "--password", help='Password', default="asdf")
parser.add_argument("-g", "--grubtype", type=int, help='Grub Install Number', default=1)
parser.add_argument("-i", "--grubpartition", help='Grub Custom Parition (if autodetection isnt working, i.e. /dev/sdb)', default=None)
parser.add_argument("-t", "--type", help='OS Type (debian, ubuntu, etc)', default="debian")
parser.add_argument("-r", "--release", help='Release Distribution', default="unstable")
parser.add_argument("-a", "--architecture", help='Architecture (amd64, i386, armhf, etc)', default="amd64")
parser.add_argument("installpath", help='Path of Installation')

# Save arguments.
args = parser.parse_args()
print("Hostname:",args.hostname)
print("Username:",args.username)
print("Full Name:",args.fullname)
print("Grub Install Number:",args.grubtype)
# Get absolute path of the given path.
absinstallpath = os.path.realpath(args.installpath)
print("Path of Installation:",absinstallpath)
print("OS Type:",args.type)
print("Release Distribution:",args.release)
DEVPART = subprocess.run('sh -c df -m | grep " \+'+absinstallpath+'$" | grep -Eo "/dev/[a-z]d[a-z]"', shell=True, stdout=subprocess.PIPE, universal_newlines=True)
grubautopart = format(DEVPART.stdout.strip())
print("Autodetect grub partition:",grubautopart)
if args.grubpartition != None and stat.S_ISBLK(os.stat(args.grubpartition).st_mode) == True:
    grubpart = args.grubpartition
else:
    grubpart = grubautopart
print("Grub partition to be used:",grubpart)
print("Architecture to install:",args.architecture)
if args.type == "ubuntu" and args.architecture == "armhf":
    osurl = "http://ports.ubuntu.com/ubuntu-ports/"
elif args.type == "ubuntu":
    osurl = "http://archive.ubuntu.com/ubuntu/"
else:
    osurl = ""
print("URL to use:", osurl)

# Exit if not root.
if not os.geteuid() == 0:
    sys.exit("\nError: Please run this script as root.\n")

if args.noprompt == False:
    input("Press Enter to continue.")

# Bootstrap the chroot environment.
BOOTSTRAPSCRIPT = ""
if args.architecture is "armhf":
    # ARM specific init here.
    BOOTSTRAPSCRIPT += """
debootstrap --foreign --no-check-gpg --include=ca-certificates --arch {DEBARCH} {DISTROCHOICE} {INSTALLPATH} {URL}
cp /usr/bin/qemu-arm-static {INSTALLPATH}/usr/bin
update-binfmts --enable
chroot {INSTALLPATH}/ /debootstrap/debootstrap --second-stage --verbose
""".format(DEBARCH=args.architecture, DISTROCHOICE=args.release, INSTALLPATH=absinstallpath, URL=osurl)
else:
    BOOTSTRAPSCRIPT += """
debootstrap --no-check-gpg --arch {DEBARCH} {DISTROCHOICE} {INSTALLPATH} {URL}
genfstab -U {INSTALLPATH} > {INSTALLPATH}/etc/fstab
""".format(DEBARCH=args.architecture, DISTROCHOICE=args.release, INSTALLPATH=absinstallpath, URL=osurl)
BOOTSTRAPSCRIPT += """
echo "America/New_York" > "{INSTALLPATH}/etc/timezone"
sed -i 's/\(127.0.0.1\tlocalhost\)\(.*\)/\1 '{NEWHOSTNAME}'/g' "{INSTALLPATH}/etc/hosts"
""".format(INSTALLPATH=absinstallpath, NEWHOSTNAME=args.hostname)
print(BOOTSTRAPSCRIPT)
# subprocess.run(BOOTSTRAPSCRIPT), shell=True, check=True)

# Copy resolv.conf into chroot (needed for arch-chroot)
# shutil.copy2("/etc/resolv.conf", "{0}/etc/resolv.conf".format(absinstallpath))

# Create and run setup script.
SETUPSCRIPT = """
#!/bin/bash

echo "Running Debian Setup Script"

# Exporting Path for chroot
export PATH=$PATH:/bin:/usr/local/sbin:/usr/sbin:/sbin

# Set hostname
echo "{HOSTNAME}" > /etc/hostname

# Set locale
# export LANG=en_US.utf8
# echo "LANG=en_US.utf8" > /etc/locale.conf
# Install locales
apt-get update
apt-get install -y locales
locale-gen --purge en_US en_US.UTF-8
dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG="en_US.UTF-8"'>/etc/default/locale
dpkg-reconfigure --frontend=noninteractive locales
update-locale
# Locale fix for gnome-terminal.
localectl set-locale LANG="en_US.UTF-8"
# Set keymap for Ubuntu
echo "console-setup	console-setup/charmap47	select	UTF-8" | debconf-set-selections

# Set timezone
[ -f /etc/localtime ] && rm -f /etc/localtime
ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

# Install lsb_release
DEBIAN_FRONTEND=noninteractive apt-get install -y lsb-release nano sudo less apt-transport-https

# Store distro being used.
DISTRO=$(lsb_release -si)
DEBRELEASE=$(lsb_release -sc)

DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common
""".format(HOSTNAME=args.hostname, USERNAME=args.username, PASSWORD=args.password, FULLNAME=args.fullname)

if args.type == "ubuntu":
    SETUPSCRIPT += """
# Restricted, universe, and multiverse for Ubuntu.
add-apt-repository restricted
add-apt-repository universe
add-apt-repository multiverse
if ! grep -i "{DEBRELEASE}-updates main" /etc/apt/sources.list; then
	add-apt-repository "deb {URL} {DEBRELEASE}-updates main restricted universe multiverse"
fi
if ! grep -i "{DEBRELEASE}-security main" /etc/apt/sources.list; then
	add-apt-repository "deb {URL} {DEBRELEASE}-security main restricted universe multiverse"
fi
if ! grep -i "{DEBRELEASE}-backports main" /etc/apt/sources.list; then
	add-apt-repository "deb {URL} {DEBRELEASE}-backports main restricted universe multiverse"
fi
""".format(DEBRELEASE=args.release, URL=osurl)
else:
    SETUPSCRIPT += """
# Contrib and non-free for normal distro
add-apt-repository main
add-apt-repository contrib
add-apt-repository non-free
if [[ "{DEBRELEASE}" != "sid" && "{DEBRELEASE}" != "unstable" && "{DEBRELEASE}" != "testing" ]] && ! grep -i "{DEBRELEASE}-updates main" /etc/apt/sources.list; then
	add-apt-repository "deb http://ftp.us.debian.org/debian {DEBRELEASE}-updates main contrib non-free"
fi
# Comment out lines containing httpredir.
sed -i '/httpredir/ s/^#*/#/' /etc/apt/sources.list
""".format(DEBRELEASE=args.release)
SETUPSCRIPT += """
apt-get update
apt-get dist-upgrade -y

# Delete defaults in sudoers for Debian.
if grep -iq $'^Defaults\tenv_reset' /etc/sudoers; then
	sed -i $'/^Defaults\tenv_reset/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tmail_badpass/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tsecure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c

"""

# Install kernel, grub.
if 2 <= args.grubtype <= 3:
    SETUPSCRIPT += """
# Install kernel and grub

"""

# Grub install selection statement.
if args.grubtype == 1:
    print("Not installing grub.")
# Use autodetected or specified grub partition.
elif args.grubtype == 2:
    # Add if partition is a block device
    if stat.S_ISBLK(os.stat(grubpart).st_mode) == True:
        SETUPSCRIPT += '\ngrub2-mkconfig -o /boot/grub2/grub.cfg'
        SETUPSCRIPT += '\ngrub2-install --target=i386-pc --recheck --debug {0}'.format(grubpart)
    else:
        print("ERROR Grub Mode 2, partition {0} is not a block device.".format(grubpart))
# Use efi partitioning
elif args.grubtype == 3:
    # Add if /boot/efi is mounted, and partition is a block device.
    if os.path.ismount("{0}/boot/efi".format(absinstallpath)) == True and stat.S_ISBLK(os.stat(grubpart).st_mode) == True:
        SETUPSCRIPT += '\ndnf install -y grub2-efi grub2-efi-modules shim efibootmgr'
        # Use standard grub method for booting efi.
        SETUPSCRIPT += '\ngrub2-mkconfig -o /boot/grub2/grub.cfg'
        SETUPSCRIPT += '\ngrub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=fedora --recheck --debug'
    else:
        print("ERROR Grub Mode 3, {0}/boot/efi isn't a mount point or {0} is not a block device.".format(absinstallpath, grubpart))

# Close and run the script.
print(SETUPSCRIPT)
# SETUPSCRIPT_PATH = absinstallpath+"/setupscript.sh"
# SETUPSCRIPT_VAR = open(SETUPSCRIPT_PATH, mode='w')
# SETUPSCRIPT_VAR.write(SETUPSCRIPT)
# SETUPSCRIPT_VAR.close()
# os.chmod(SETUPSCRIPT_PATH, 0o777)
# subprocess.run("arch-chroot {0} /setupscript.sh".format(absinstallpath), shell=True)
# Remove after running
# os.remove(SETUPSCRIPT_PATH)
# os.remove("{0}/etc/resolv.conf".format(absinstallpath))
print("Script finished successfully.")
