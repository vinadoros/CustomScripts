#!/usr/bin/env python3

# Python includes.
import argparse
from datetime import datetime, timedelta
import glob
import grp
import os
import platform
import pwd
import shutil
import subprocess
import sys

print("Running {0}".format(__file__))

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
if os.getenv("SUDO_USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("SUDO_USER")
elif os.getenv("USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR = pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP=grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
ROOTHOME=os.path.expanduser("~")
USERHOME=os.path.expanduser("~{0}".format(USERNAMEVAR))
MACHINEARCH = platform.machine()

# Get arguments
parser = argparse.ArgumentParser(description='Build Ubuntu LiveCD.')
parser.add_argument("-n", "--noprompt",help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolderroot", help='Location of Working Folder (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-o", "--output", help='Output Location of ISO (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-f", "--flavor", help='Ubuntu Flavor', default="zesty")

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolderroot+"/ubuiso_buildfolder")
print("Root of Working Folder:",buildfolder)
outfolder = os.path.abspath(args.output)
print("ISO Output Folder:",outfolder)
if not os.path.isdir(outfolder):
    sys.exit("\nError, ensure {0} is a folder.".format(outfolder))

if args.noprompt is False:
    input("Press Enter to continue.")

# Ensure that certain commands exist.
subprocess.run("apt-get update; apt-get install -y live-build debootstrap genisoimage syslinux syslinux-utils isolinux xorriso rsync time memtest86+ syslinux-themes-ubuntu-xenial gfxboot-theme-ubuntu livecd-rootfs", shell=True)

# Make the build folder if it doesn't exist
os.makedirs(buildfolder, 0o777, exist_ok=True)

# Copy over autoconfig
if os.path.isdir(buildfolder+"/auto"):
    shutil.rmtree(buildfolder+"/auto")
shutil.copytree("/usr/share/livecd-rootfs/live-build/auto", buildfolder+"/auto")

# Configure and cleanthe live build
# https://debian-live.alioth.debian.org/live-manual/stable/manual/html/live-manual.en.html
subprocess.run("""
cd {0}

export SUITE={1}
export ARCH=amd64
export PROJECT=ubuntu-mate
export MIRROR=http://archive.ubuntu.com/ubuntu/
export BINARYFORMAT=iso-hybrid
export LB_SYSLINUX_THEME=ubuntu-xenial

sed -i 's@#! /bin/sh@#! /bin/sh -x@g' {0}/auto/config {0}/auto/build

lb clean
lb config --initramfs-compression=gzip
""".format(buildfolder, args.flavor), shell=True)

# Add packages
PACKAGELIST="""
# Desktop utils
caja-open-terminal
caja-gksu
dconf-editor
gnome-keyring
dconf-cli
leafpad
midori
gvfs
avahi-daemon
avahi-discover
# CLI Utilities
sudo
ssh
tmux
nano
curl
rsync
less
iotop
git
# Provides the mkpasswd utility
whois
# Recovery and Backup utils
clonezilla
gparted
fsarchiver
gnome-disk-utility
btrfs-tools
f2fs-tools
xfsprogs
dmraid
mdadm
chntpw
debootstrap
# VM Utilities
dkms
spice-vdagent
qemu-guest-agent
open-vm-tools
open-vm-tools-dkms
open-vm-tools-desktop
virtualbox-guest-utils
virtualbox-guest-dkms
"""
pkgfolder=buildfolder+"/config/package-lists"
pkgfile=pkgfolder+"/custom.list.chroot"
os.makedirs(pkgfolder, 0o777, exist_ok=True)
print("Writing {0}".format(pkgfile))
with open(pkgfile, 'w') as pkgfile_write:
    pkgfile_write.write(PACKAGELIST)

# Add repositories
REPOLIST='deb http://us.archive.ubuntu.com/ubuntu {0} main restricted universe multiverse'.format(args.flavor)
repofolder=buildfolder+"/config/archives"
binaryrepofile=repofolder+"/your-repository.list.binary"
chrootrepofile=repofolder+"/your-repository.list.chroot"
os.makedirs(repofolder, 0o777, exist_ok=True)
print("Writing {0}".format(binaryrepofile))
with open(binaryrepofile, 'w') as binaryrepofile_write:
    binaryrepofile_write.write(REPOLIST)
print("Writing {0}".format(chrootrepofile))
with open(chrootrepofile, 'w') as chrootrepofile_write:
    chrootrepofile_write.write(REPOLIST)

# Add chroot script
CHROOTSCRIPT = """#!/bin/bash -x
# Modify ssh config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config

# Install CustomScripts
git clone "https://github.com/vinadoros/CustomScripts.git" "/CustomScripts"

# --- BEGIN Update CustomScripts on startup ---

cat >/etc/systemd/system/updatecs.service <<EOL
[Unit]
Description=updatecs service
Requires=network-online.target
After=network.target nss-lookup.target network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -c "cd /CustomScripts; git pull"
Restart=on-failure
RestartSec=3s
TimeoutStopSec=7s

[Install]
WantedBy=graphical.target
EOL
systemctl enable updatecs.service

# --- END Update CustomScripts on startup ---

# Run MATE Settings script on desktop startup.
cat >"/etc/xdg/autostart/matesettings.desktop" <<"EOL"
[Desktop Entry]
Name=MATE Settings Script
Exec=/CustomScripts/DSet.sh
Terminal=false
Type=Application
EOL

# Autoset resolution
cat >"/etc/xdg/autostart/ra.desktop" <<"EOL"
[Desktop Entry]
Name=Autoresize Resolution
Exec=/usr/local/bin/ra.sh
Terminal=false
Type=Application
EOL
cat >"/usr/local/bin/ra.sh" <<'EOL'
#!/bin/bash
while true; do
	sleep 5
	if [ -z $DISPLAY ]; then
		echo "Display variable not set. Exiting."
		exit 1;
	fi
	xhost +localhost
	# Detect the display output from xrandr.
	RADISPLAYS=$(xrandr --listmonitors | awk '{print $4}')
	while true; do
		sleep 1
		# Loop through every detected display and autoset them.
		for disp in ${RADISPLAYS[@]}; do
			xrandr --output $disp --auto
		done
	done
done
EOL
chmod a+rwx /usr/local/bin/ra.sh

# Set computer to not sleep on lid close
if ! grep -Fxq "HandleLidSwitch=lock" /etc/systemd/logind.conf; then
	echo 'HandleLidSwitch=lock' >> /etc/systemd/logind.conf
fi

# Add CustomScripts to path
SCRIPTBASENAME="/CustomScripts"
if ! grep "$SCRIPTBASENAME" /root/.bashrc; then
	cat >>/root/.bashrc <<EOLBASH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME
fi
EOLBASH
fi
if ! grep "$SCRIPTBASENAME" /home/ubuntu/.bashrc; then
	cat >>/home/ubuntu/.bashrc <<EOLBASH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME:/sbin:/usr/sbin
fi
EOLBASH
fi

# Remove apps
apt-get remove -y ubiquity ubiquity-casper
apt-get remove -y ubuntu-mate-welcome

# Set root password
passwd -u root
echo "root:asdf" | chpasswd

"""
chroothookfolder = buildfolder+"/config/hooks"
chroothookfile = chroothookfolder+"/custom.hook.chroot"
os.makedirs(chroothookfolder, 0o777, exist_ok=True)
print("Writing {0}".format(chroothookfile))
with open(chroothookfile, 'w') as chroothookfile_write:
    chroothookfile_write.write(CHROOTSCRIPT)

# Add binary script
BINARYSCRIPT = """#!/bin/bash -x
# Fix kernel and initrd locations.
cp -a {0}/chroot/boot/vmlinuz-*-generic {0}/binary/casper/vmlinuz
cp -a {0}/chroot/boot/initrd.img-*-generic {0}/binary/casper/initrd.lz
""".format(buildfolder)
binaryhookfolder = buildfolder+"/config/hooks"
binaryhookfile = binaryhookfolder+"/custom.hook.binary"
os.makedirs(binaryhookfolder, 0o777, exist_ok=True)
print("Writing {0}".format(binaryhookfile))
with open(binaryhookfile, 'w') as binaryhookfile_write:
    binaryhookfile_write.write(BINARYSCRIPT)

# Build the live image
subprocess.run("cd {0}; time lb build".format(buildfolder), shell=True)

# Make normal user owner of build folder.
subprocess.run("chown {0}:{1} -R {2}".format(USERNAMEVAR, USERGROUP, buildfolder), shell=True)

# Find the iso
# https://stackoverflow.com/questions/3964681/find-all-files-in-directory-with-extension-txt-in-python#3964691
# https://stackoverflow.com/questions/2186525/use-a-glob-to-find-files-recursively-in-python
for filename in glob.iglob(buildfolder+"/livecd.*.iso"):
    print("Detected: "+filename)
    # # Run isohybrid on the file in case it failed.
    # subprocess.run("isohybrid {0}".format(filename))
    # Make the iso world rwx
    os.chmod(filename, 0o777)
    # Move the iso to the output folder
    subprocess.run("cd {2}; rsync -aP {0} {1}; sync".format(filename, outfolder+"/", buildfolder), shell=True)
