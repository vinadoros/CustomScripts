#!/usr/bin/env python3
"""Create a Fedora live-cd."""

# Python includes.
import argparse
from datetime import datetime
import os
import subprocess
import sys
import time
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

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

### Prep Environment ###
# https://fedoraproject.org/wiki/Livemedia-creator-_How_to_create_and_use_a_Live_CD
# https://github.com/rhinstaller/lorax/blob/master/docs/livemedia-creator.rst
ks_text = """
%include /usr/share/spin-kickstarts/fedora-live-base.ks
%include /usr/share/spin-kickstarts/fedora-mate-common.ks
%include /usr/share/spin-kickstarts/fedora-live-minimization.ks

part / --size 6144

%post
cat >> /etc/rc.d/init.d/livesys << EOF


# make the installer show up
if [ -f /usr/share/applications/liveinst.desktop ]; then
  # Show harddisk install in shell dash
  sed -i -e 's/NoDisplay=true/NoDisplay=false/' /usr/share/applications/liveinst.desktop ""
fi
mkdir /home/liveuser/Desktop
cp /usr/share/applications/liveinst.desktop /home/liveuser/Desktop

# and mark it as executable
chmod +x /home/liveuser/Desktop/liveinst.desktop

# rebuild schema cache with any overrides we installed
glib-compile-schemas /usr/share/glib-2.0/schemas

# set up lightdm autologin
sed -i 's/^#autologin-user=.*/autologin-user=liveuser/' /etc/lightdm/lightdm.conf
sed -i 's/^#autologin-user-timeout=.*/autologin-user-timeout=0/' /etc/lightdm/lightdm.conf
#sed -i 's/^#show-language-selector=.*/show-language-selector=true/' /etc/lightdm/lightdm-gtk-greeter.conf

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
# Get Dates
currentdatetime = time.strftime("%Y-%m-%d_%H%M")
shortdate = time.strftime("%Y%m%d")
beforetime = datetime.now()
# Start Build
subprocess.run("livemedia-creator --ks {ks} --no-virt --resultdir {resultdir} --project Fedora-CustomLive --make-iso --volid Fedora-CustomLive-{shortdate} --iso-only --iso-name Fedora-CustomLive-{datetime}.iso --releasever 27 --title Fedora-CustomLive --macboot".format(ks=ks_flat, resultdir=resultsfolder, datetime=currentdatetime, shortdate=shortdate), shell=True)
print("Build completed in :", datetime.now() - beforetime)