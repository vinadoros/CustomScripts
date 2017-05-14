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
if not os.geteuid() == 0:
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
ROOTHOME=os.path.expanduser("~")
USERHOME=os.path.expanduser("~{0}".format(USERNAMEVAR))
MACHINEARCH = platform.machine()

# Get arguments
parser = argparse.ArgumentParser(description='Build Ubuntu LiveCD.')
parser.add_argument("-n", "--noprompt",help='Do not prompt.', action="store_true")
parser.add_argument("-c", "--clean",help='Clean the working folder.', action="store_true")
parser.add_argument("-w", "--workfolderroot", help='Location of Working Folder (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-o", "--output", help='Output Location of ISO (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-f", "--flavor", help='Ubuntu Flavor', default="zesty")

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolderroot+"/ubuiso2_buildfolder")
chrootfolder = buildfolder+"/chroot"
print("Root of Working Folder:",buildfolder)
outfolder = os.path.abspath(args.output)
print("ISO Output Folder:",outfolder)
if not os.path.isdir(outfolder):
    sys.exit("\nError, ensure {0} is a folder.".format(outfolder))

if args.noprompt is False:
    input("Press Enter to continue.")

# Ensure that certain commands exist.
subprocess.run("apt-get update; apt-get install -y debootstrap systemd-container genisoimage syslinux syslinux-utils isolinux xorriso rsync time systemd-container", shell=True)

# Clean the build folder if it exists
if args.clean is True and os.path.isdir(buildfolder):
    print("Removing {0}".format(buildfolder))
    shutil.rmtree(buildfolder)
# Make the build folder if it doesn't exist
os.makedirs(buildfolder, 0o777, exist_ok=True)

# Debootstrap the filesystem
subprocess.run("""
cd {0}
mkdir -p {2}
debootstrap --arch amd64 {1} {2} http://archive.ubuntu.com/ubuntu/
""".format(buildfolder, args.flavor, chrootfolder), shell=True)

# Add packages
PACKAGELIST="""
# Desktop utils
ubuntu-mate-desktop
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
# pkgfolder=buildfolder+"/config/package-lists"
# pkgfile=pkgfolder+"/custom.list.chroot"
# os.makedirs(pkgfolder, 0o777, exist_ok=True)
# print("Writing {0}".format(pkgfile))
# with open(pkgfile, 'w') as pkgfile_write:
#     pkgfile_write.write(PACKAGELIST)


# Add chroot script
CHROOTSCRIPT = """#!/bin/bash -x

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confnew" ubuntu-minimal ubuntu-standard linux-generic linux-firmware git sudo ssh tmux nano curl rsync less iotop

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

# Set root password
passwd -u root
echo "root:asdf" | chpasswd

# Install livecd packages
apt-get install -y casper lupin-casper
"""
setupscript = chrootfolder+"/setupscript.sh"
print("Writing {0}".format(setupscript))
with open(setupscript, 'w') as setupscript_write:
    setupscript_write.write(CHROOTSCRIPT)
os.chmod(setupscript, 0o777)

# Remove resolv.conf before chroot
if os.path.exists("{0}/etc/resolv.conf".format(chrootfolder)):
    os.remove("{0}/etc/resolv.conf".format(chrootfolder))

# Run chroot script
subprocess.run("""
systemd-nspawn -D {0} /setupscript.sh
""".format(chrootfolder), shell=True)

# Run final prep
subprocess.run("""
cd {0}
mkdir -p image/casper image/isolinux image/install
cp -a {1}/boot/vmlinuz-*-generic {0}/image/casper/vmlinuz
cp -a {1}/boot/initrd.img-*-generic {0}/image/casper/initrd.lz
cp /usr/lib/ISOLINUX/isolinux.bin {0}/image/isolinux/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 {0}/image/isolinux/
cp /boot/memtest86+.bin {0}/image/install/memtest

chroot chroot dpkg-query -W --showformat='${{Package}} ${{Version}}\n' | tee image/casper/filesystem.manifest
cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for i in $REMOVE
do
    sudo sed -i "/$i/d" image/casper/filesystem.manifest-desktop
done

cat > {0}/image/isolinux/isolinux.cfg <<'EOL'
DEFAULT live
LABEL live
  menu label ^Start or install Ubuntu Remix
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash --
LABEL check
  menu label ^Check CD for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
LABEL memtest
  menu label ^Memory test
  kernel /install/memtest
  append -
LABEL hd
  menu label ^Boot from first hard disk
  localboot 0x80
  append -
DISPLAY isolinux.txt
TIMEOUT 5
PROMPT 1
EOL

cd {0}
mksquashfs chroot image/casper/filesystem.squashfs -e boot
cd image && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt
cd {0}

cd {0}/image
mkisofs -r -V "ubuntu-custom" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o {2}/ubuntu-custom.iso .
isohybrid {2}/ubuntu-custom.iso

""".format(buildfolder, chrootfolder, outfolder), shell=True)
