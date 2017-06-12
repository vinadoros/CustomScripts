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
parser = argparse.ArgumentParser(description='Build Debian LiveCD.')
parser.add_argument("-n", "--noprompt",help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolderroot", help='Location of Working Folder (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-o", "--output", help='Output Location of ISO (i.e. {0})'.format(USERHOME), default=USERHOME)

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolderroot+"/debiso_buildfolder")
print("Root of Working Folder:",buildfolder)
outfolder = os.path.abspath(args.output)
print("ISO Output Folder:",outfolder)
if not os.path.isdir(outfolder):
    sys.exit("\nError, ensure {0} is a folder.".format(outfolder))

if args.noprompt is False:
    input("Press Enter to continue.")

# Ensure that certain commands exist.
subprocess.run("apt-get update; apt-get install -y live-build syslinux isolinux xorriso rsync time", shell=True)

# Make the build folder if it doesn't exist
os.makedirs(buildfolder, 0o777, exist_ok=True)

# Configure and clean the live build
subprocess.run('cd {0}; lb clean; lb config --bootappend-live "boot=live components timezone=America/New_York"'.format(buildfolder), shell=True)

# Copy over autoconfig
if os.path.isdir(buildfolder+"/auto"):
    shutil.rmtree(buildfolder+"/auto")
shutil.copytree("/usr/share/doc/live-build/examples/auto", buildfolder+"/auto")

# Add packages
PACKAGELIST="""
# Desktop utils
#task-mate-desktop
mate-desktop-environment
lightdm
network-manager-gnome
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
REPOLIST='deb http://ftp.us.debian.org/debian unstable main contrib non-free'
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

# Add bootloader config
if os.path.isdir(buildfolder+"/config/bootloaders"):
    shutil.rmtree(buildfolder+"/config/bootloaders")
os.makedirs(buildfolder+"/config/bootloaders/", exist_ok=True)
shutil.copytree("/usr/share/live/build/bootloaders/isolinux", buildfolder+"/config/bootloaders/isolinux", ignore_dangling_symlinks=True)
shutil.copy2("/usr/lib/ISOLINUX/isolinux.bin", buildfolder+"/config/bootloaders/isolinux")
shutil.copy2("/usr/lib/syslinux/modules/bios/vesamenu.c32", buildfolder+"/config/bootloaders/isolinux")
subprocess.run("sed -i 's/^timeout .*/timeout 10/g' {0}".format(buildfolder+"/config/bootloaders/isolinux/isolinux.cfg"), shell=True)

# Add chroot script
CHROOTSCRIPT="""#!/bin/bash -x

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

"""
chroothookfolder=buildfolder+"/config/hooks/normal"
chroothookfile=chroothookfolder+"/custom.hook.chroot"
os.makedirs(chroothookfolder, 0o777, exist_ok=True)
print("Writing {0}".format(chroothookfile))
with open(chroothookfile, 'w') as chroothookfile_write:
    chroothookfile_write.write(CHROOTSCRIPT)

# Boot-time hooks
BOOTHOOKSCRIPT="""#!/bin/bash -x
echo "live-config: 2000-usercustomization"

# Set root password
passwd -u root
echo "root:asdf" | chpasswd

# Add CustomScripts to path
SCRIPTBASENAME="/CustomScripts"
if ! grep "$SCRIPTBASENAME" /root/.bashrc; then
	cat >>/root/.bashrc <<EOLBASH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME
fi
EOLBASH
fi
if ! grep "$SCRIPTBASENAME" /home/user/.bashrc; then
	cat >>/home/user/.bashrc <<EOLBASH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME:/sbin:/usr/sbin
fi
EOLBASH
fi
"""
boothookfolder=buildfolder+"/config/includes.chroot/lib/live/config"
boothookfile=boothookfolder+"/2000-usercustomization"
os.makedirs(boothookfolder, 0o777, exist_ok=True)
print("Writing {0}".format(boothookfile))
with open(boothookfile, 'w') as boothookfile_write:
    boothookfile_write.write(BOOTHOOKSCRIPT)
os.chmod(boothookfile, 0o755)

# Build the live build
subprocess.run("cd {0}; time lb build".format(buildfolder), shell=True)

# Make normal user owner of build folder.
subprocess.run("chown {0}:{1} -R {2}".format(USERNAMEVAR, USERGROUP, buildfolder), shell=True)

# Find the iso
# https://stackoverflow.com/questions/3964681/find-all-files-in-directory-with-extension-txt-in-python#3964691
# https://stackoverflow.com/questions/2186525/use-a-glob-to-find-files-recursively-in-python
for filename in glob.iglob(buildfolder+"/*.hybrid.iso"):
    print("Detected: "+filename)
    # Make the iso world rwx
    os.chmod(filename, 0o777)
    # Move the iso to the output folder
    subprocess.run("cd {2}; rsync -aP {0} {1}; sync".format(filename, outfolder+"/", buildfolder), shell=True)
