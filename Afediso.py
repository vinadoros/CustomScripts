#!/usr/bin/env python3
"""Create a Fedora live-cd."""

# Python includes.
import argparse
from datetime import datetime
import os
import shutil
import subprocess
import sys
import time
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Exit if not root.
CFunc.is_root(True)

# Get the root user's home folder.
USERHOME = os.path.expanduser("~root")

# Get arguments
parser = argparse.ArgumentParser(description='Build Fedora LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolderroot", help='Location of Working Folder (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-o", "--output", help='Output Location of ISO (i.e. {0})'.format(USERHOME), default=USERHOME)

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolderroot)
print("Root of Working Folder:", buildfolder)
outfolder = os.path.abspath(args.output)
print("ISO Output Folder:", outfolder)
if not os.path.isdir(outfolder):
    sys.exit("\nError, ensure {0} is a folder.".format(outfolder))

if args.noprompt is False:
    input("Press Enter to continue.")

# Modify lorax grub config
subprocess.run('sed -i "s/^default=.*/default=0/g" /usr/share/lorax/templates.d/99-generic/live/config_files/x86/grub.conf /usr/share/lorax/templates.d/99-generic/live/config_files/x86/grub2-efi.cfg /usr/share/lorax/templates.d/99-generic/config_files/x86/grub.conf /usr/share/lorax/templates.d/99-generic/config_files/x86/grub2-efi.cfg', shell=True)
subprocess.run('sed -i "s/^timeout.*/timeout 1/g" /usr/share/lorax/templates.d/99-generic/live/config_files/x86/grub.conf /usr/share/lorax/templates.d/99-generic/live/config_files/x86/grub2-efi.cfg /usr/share/lorax/templates.d/99-generic/config_files/x86/grub.conf /usr/share/lorax/templates.d/99-generic/config_files/x86/grub2-efi.cfg', shell=True)
subprocess.run('sed -i "s/^timeout.*/timeout 10/g" /usr/share/lorax/templates.d/99-generic/config_files/x86/isolinux.cfg /usr/share/lorax/templates.d/99-generic/live/config_files/x86/isolinux.cfg', shell=True)
subprocess.run('sed -i "/menu default/d" /usr/share/lorax/templates.d/99-generic/config_files/x86/isolinux.cfg /usr/share/lorax/templates.d/99-generic/live/config_files/x86/isolinux.cfg', shell=True)
subprocess.run('sed -i "/label linux/a \ \ menu default" /usr/share/lorax/templates.d/99-generic/config_files/x86/isolinux.cfg /usr/share/lorax/templates.d/99-generic/live/config_files/x86/isolinux.cfg', shell=True)

### Prep Environment ###
# https://fedoraproject.org/wiki/Livemedia-creator-_How_to_create_and_use_a_Live_CD
# https://github.com/rhinstaller/lorax/blob/master/docs/livemedia-creator.rst
ks_text = """
%include /usr/share/spin-kickstarts/fedora-live-base.ks
%include /usr/share/spin-kickstarts/fedora-live-minimization.ks

part / --size 6144

%packages

# Desktop Environment
@mate-desktop
@mate-applications
@networkmanager-submodules

# CLI Utils
git
zsh
nano
tmux
iotop
rsync
p7zip
p7zip-plugins
zip
unzip
openssh-server
openssh-clients
avahi
chntpw

# Filesystem utils
fstransform
partclone
btrfs-progs
f2fs-tools
# Needs rpmfusion-free
# fuse-exfat
# exfat-utils
cryptsetup
device-mapper

# VM Utils
spice-vdagent
qemu-guest-agent
open-vm-tools
open-vm-tools-desktop

# Graphical Utils
gnome-disk-utility
gparted

# For clonezilla
dialog

# Exclusions
-thunderbird
-pidgin

%end


%post

# Set DNS nameservers
echo -e "nameserver 1.0.0.1\\nnameserver 1.1.1.1\\nnameserver 2606:4700:4700::1111\\nnameserver 2606:4700:4700::1001" > /etc/resolv.conf

# Pull CustomScripts
git clone https://github.com/ramesh45345/CustomScripts /opt/CustomScripts

# ShellConfig
python3 /opt/CustomScripts/CShellConfig.py

# Clonezilla
git clone https://github.com/stevenshiau/drbl drbl
cd drbl
make all
make install
cd ..
rm -rf drbl
git clone https://github.com/stevenshiau/clonezilla clonezilla
cd clonezilla
make all
make install
cd ..
rm -rf clonezilla

# Disable selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config /etc/sysconfig/selinux

# Delete defaults in sudoers.
if grep -iq $'^Defaults    secure_path' /etc/sudoers; then
    sed -e 's/^Defaults    env_reset$/Defaults    !env_reset/g' -i /etc/sudoers
    sed -i $'/^Defaults    mail_badpass/ s/^#*/#/' /etc/sudoers
    sed -i $'/^Defaults    secure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c

# Script run on boot
cat >> /etc/rc.d/init.d/livesys << EOF

# Update CustomScripts
cd /opt/CustomScripts
git pull &

# Change shell to zsh
chsh -s /bin/zsh root
chsh -s /bin/zsh liveuser
# Set path
echo 'PATH=$PATH:/opt/CustomScripts' | tee -a /root/.bashrc /home/liveuser/.bashrc /root/.zshrc /home/liveuser/.zshrc

# LightDM Autologin
sed -i 's/^#autologin-user=.*/autologin-user=liveuser/' /etc/lightdm/lightdm.conf
# sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
echo -e "[SeatDefaults]\nautologin-user=liveuser\nuser-session=mate" > /etc/lightdm/lightdm.conf.d/12-autologin.conf
groupadd autologin
gpasswd -a liveuser autologin

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set MATE as default session, otherwise login will fail
sed -i 's/^#user-session=.*/user-session=mate/' /etc/lightdm/lightdm.conf

# Turn off PackageKit-command-not-found while uninstalled
if [ -f /etc/PackageKit/CommandNotFound.conf ]; then
  sed -i -e 's/^SoftwareSourceSearch=true/SoftwareSourceSearch=false/' /etc/PackageKit/CommandNotFound.conf
fi

# no updater applet in live environment
rm -f /etc/xdg/autostart/org.mageia.dnfdragora-updater.desktop

# make sure to set the right permissions and selinux contexts
chown -R liveuser:liveuser /home/liveuser/
restorecon -R /home/liveuser/
EOF

%end
"""
ks_path = os.path.join(buildfolder, "fediso.ks")
with open(ks_path, 'w') as ks_write:
    ks_write.write(ks_text)

# Flatten kickstart file
ks_flat = os.path.join(buildfolder, "flat_fediso.ks")
subprocess.run("ksflatten --config {0} -o {1}".format(ks_path, ks_flat), shell=True)

### Build LiveCD ###
resultsfolder = os.path.join(buildfolder, "results")
if os.path.isdir(resultsfolder):
    shutil.rmtree(resultsfolder)
# Get Dates
currentdatetime = time.strftime("%Y-%m-%d_%H%M")
shortdate = time.strftime("%Y%m%d")
beforetime = datetime.now()
isoname = "Fedora-CustomLive-{0}.iso".format(currentdatetime)
# Start Build
subprocess.run("livemedia-creator --ks {ks} --no-virt --resultdir {resultdir} --logfile {outfolder}/livemedia.log --project Fedora-CustomLive --make-iso --volid Fedora-CustomLive-{shortdate} --iso-only --iso-name {isoname} --releasever 29 --title Fedora-CustomLive --macboot --no-virt".format(ks=ks_flat, resultdir=resultsfolder, isoname=isoname, shortdate=shortdate, outfolder=outfolder), shell=True)
subprocess.run("chmod a+rw -R {0}".format(buildfolder), shell=True)
print('Run to test in iso folder: "qemu-system-x86_64 -enable-kvm -m 2048 ./{0}"'.format(isoname))
print("Build completed in :", datetime.now() - beforetime)
