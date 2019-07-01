#!/usr/bin/env python3
"""Create a debian live-cd using live-build."""

# Python includes.
import argparse
from datetime import datetime
import glob
import os
import shutil
import subprocess
import sys
import time
import urllib.request

print("Running {0}".format(__file__))

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get the root user's home folder.
USERHOME = os.path.expanduser("~root")

# Get arguments
parser = argparse.ArgumentParser(description='Build Debian LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolderroot", help='Location of Working Folder (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-o", "--output", help='Output Location of ISO (i.e. {0})'.format(USERHOME), default=USERHOME)

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolderroot+"/debiso_buildfolder")
print("Root of Working Folder:", buildfolder)
outfolder = os.path.abspath(args.output)
print("ISO Output Folder:", outfolder)
if not os.path.isdir(outfolder):
    sys.exit("\nError, ensure {0} is a folder.".format(outfolder))

if args.noprompt is False:
    input("Press Enter to continue.")


### Functions ###
def subpout(cmd):
    """Get output from subprocess"""
    output = subprocess.run("{0}".format(cmd), shell=True, stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return output
def downloadfile(download_url, download_localpath):
    """Retrieve a file and return its fullpath and filename"""
    # Get filename for extensions
    download_fileinfo = urllib.parse.urlparse(download_url)
    download_filename = urllib.parse.unquote(os.path.basename(download_fileinfo.path))
    download_fullpath = download_localpath + "/" + download_filename
    # Download the file.
    print("Downloading {0}.".format(download_filename))
    urllib.request.urlretrieve(download_url, download_fullpath)
    if not os.path.isfile(download_fullpath):
        sys.exit("File {0} not downloaded. Exiting.".format(download_filename))
    return (download_fullpath, download_filename)


### Begin Prep Work ###
# Make the build folder if it doesn't exist
os.makedirs(buildfolder, 0o777, exist_ok=True)

# Configure and clean the live build
subprocess.run('cd {0}; lb clean; lb config --distribution sid --archive-areas "main contrib non-free" --bootappend-live "boot=live components timezone=America/New_York"'.format(buildfolder), shell=True)

# Copy over autoconfig
if os.path.isdir(buildfolder+"/auto"):
    shutil.rmtree(buildfolder+"/auto")
shutil.copytree("/usr/share/doc/live-build/examples/auto", buildfolder+"/auto")

# Add packages
PACKAGELIST = """
# Desktop utils
mate-desktop-environment
lightdm
network-manager-gnome
caja-open-terminal
dconf-editor
gnome-keyring
dconf-cli
chromium
gvfs
avahi-daemon
avahi-discover
# CLI Utilities
coreutils
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
screen
gparted
fsarchiver
gnome-disk-utility
btrfs-progs
f2fs-tools
xfsprogs
dmraid
mdadm
lvm2
chntpw
debootstrap
efibootmgr
# Weresync
python3-pkg-resources
weresync
# VM Utilities
dkms
spice-vdagent
qemu-guest-agent
open-vm-tools
open-vm-tools-desktop
virtualbox-guest-utils
virtualbox-guest-dkms
virtualbox-guest-x11
build-essential
"""
pkgfolder = buildfolder+"/config/package-lists"
pkgfile = pkgfolder+"/custom.list.chroot"
os.makedirs(pkgfolder, 0o777, exist_ok=True)
print("Writing {0}".format(pkgfile))
with open(pkgfile, 'w') as pkgfile_write:
    pkgfile_write.write(PACKAGELIST)

# # Add repositories
# REPOLIST='deb http://ftp.us.debian.org/debian unstable main contrib non-free'
# repofolder=buildfolder+"/config/archives"
# binaryrepofile=repofolder+"/your-repository.list.binary"
# chrootrepofile=repofolder+"/your-repository.list.chroot"
# os.makedirs(repofolder, 0o777, exist_ok=True)
# print("Writing {0}".format(binaryrepofile))
# with open(binaryrepofile, 'w') as binaryrepofile_write:
#     binaryrepofile_write.write(REPOLIST)
# print("Writing {0}".format(chrootrepofile))
# with open(chrootrepofile, 'w') as chrootrepofile_write:
#     chrootrepofile_write.write(REPOLIST)

# # Add packages
# PACKAGEFOLDER = buildfolder+"/config/packages.chroot"
# os.makedirs(PACKAGEFOLDER, exist_ok=True)
# # qt5-fsarchiver
# qtfsfile = downloadfile("https://downloads.sourceforge.net/project/qt4-fsarchiver/qt5-fsarchiver/deb-Pakete/Debian/Debian9.3/qt5-fsarchiver-0.8.2-0-amd64.deb", PACKAGEFOLDER)
# subprocess.run("dpkg-name -o {0}".format(qtfsfile[0]), shell=True)

# # Add bootloader config
if os.path.isdir(buildfolder+"/config/bootloaders"):
    shutil.rmtree(buildfolder+"/config/bootloaders")
os.makedirs(buildfolder+"/config/bootloaders/", exist_ok=True)
# Copy isolinux
shutil.copytree("/usr/share/live/build/bootloaders/isolinux", buildfolder+"/config/bootloaders/isolinux", ignore_dangling_symlinks=False)
# Modify isolinux timeout
subprocess.run("sed -i 's/^timeout .*/timeout 10/g' {0}".format(buildfolder+"/config/bootloaders/isolinux/isolinux.cfg"), shell=True)

# Add chroot script
CHROOTSCRIPT = """#!/bin/bash -x

# Modify ssh config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config

# Install CustomScripts
git clone "https://github.com/ramesh45345/CustomScripts.git" "/CustomScripts"

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
Exec=/CustomScripts/Dset.sh
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

# VM services
systemctl enable virtualbox-guest-utils

"""
chroothookfolder = buildfolder+"/config/hooks/normal"
chroothookfile = chroothookfolder+"/custom.hook.chroot"
os.makedirs(chroothookfolder, 0o777, exist_ok=True)
print("Writing {0}".format(chroothookfile))
with open(chroothookfile, 'w') as chroothookfile_write:
    chroothookfile_write.write(CHROOTSCRIPT)

# Boot-time hooks
BOOTHOOKSCRIPT = """#!/bin/bash -x
echo "live-config: 2000-usercustomization"

# Set root password
passwd -u root
echo "root:asdf" | chpasswd

# Set user password
echo "user:asdf" | chpasswd

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
boothookfolder = buildfolder+"/config/includes.chroot/lib/live/config"
boothookfile = boothookfolder+"/2000-usercustomization"
os.makedirs(boothookfolder, 0o777, exist_ok=True)
print("Writing {0}".format(boothookfile))
with open(boothookfile, 'w') as boothookfile_write:
    boothookfile_write.write(BOOTHOOKSCRIPT)
os.chmod(boothookfile, 0o755)

### Begin Actual Build ###
# Build the live build
beforetime = datetime.now()
subprocess.run("cd {0}; lb build".format(buildfolder), shell=True)
print("Build completed in :", datetime.now() - beforetime)

# Find the iso
# https://stackoverflow.com/questions/3964681/find-all-files-in-directory-with-extension-txt-in-python#3964691
# https://stackoverflow.com/questions/2186525/use-a-glob-to-find-files-recursively-in-python
for filename in glob.iglob(buildfolder+"/*.hybrid.iso"):
    print("Detected: "+filename)
    # Get basename and dirname of file.
    basefilename = os.path.basename(filename)
    dirfilename = os.path.dirname(filename)
    # New file name for file.
    currentdatetime = time.strftime("%Y-%m-%d_%H%M")
    newfilename = basefilename.replace("hybrid", currentdatetime)
    # Make the iso world rwx
    os.chmod(filename, 0o777)
    # Move the iso to the output folder
    subprocess.run("""
    cd {buildfolder}
    rsync -aP "{filename}" "{output}"
    mv "{output}/{oldfilename}" "{output}/{newfilename}"
    sync
    """.format(filename=filename, output=outfolder+"/", buildfolder=buildfolder, origfolder=dirfilename, oldfilename=basefilename, newfilename=newfilename), shell=True)
