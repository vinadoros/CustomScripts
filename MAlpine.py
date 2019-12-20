#!/usr/bin/env python3
"""Install Alpine Software"""

# Python includes.
import argparse
import os
import re
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]


### Functions ###
def apkinstall(apks):
    """Install packages with apk."""
    subprocess.run("apk add {0}".format(apks), shell=True)


# Get arguments
parser = argparse.ArgumentParser(description='Install Alpine Software.')
parser.add_argument("-d", "--desktop", help='Desktop Environment (i.e. gnome, kde, mate, etc)')
parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)

# Exit if not root.
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)

# Get VM State
vmstatus = CFunc.getvmstate()


# Uncomment community repo in repositories
with open(os.path.join(os.sep, "etc", "apk", "repositories"), 'r') as sfile:
    lines = sfile.readlines()
with open(os.path.join(os.sep, "etc", "apk", "repositories"), 'w') as tfile:
    # Replace the # on the 3rd line.
    lines[2] = re.sub("#", "", lines[2])
    tfile.writelines(lines)
subprocess.run("apk upgrade --update-cache --available", shell=True)

### Software ###
apkinstall("git nano sudo bash zsh")
# Setup Sudo
subprocess.run("sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /etc/sudoers", shell=True)
# Avahi
apkinstall("avahi")
subprocess.run("rc-update add avahi-daemon", shell=True)


# GUI Packages
if not args.nogui:
    # Dbus/udev
    apkinstall("dbus dbus-x11 udev")
    subprocess.run("rc-update add dbus", shell=True)
    subprocess.run("rc-update add udev", shell=True)
    # Xorg
    subprocess.run("setup-xorg-base xf86-input-keyboard xf86-input-synaptics xf86-input-evdev xf86-input-libinput xf86-input-mouse xf86-input-vmmouse xf86-video-modesetting xf86-video-intel xf86-video-dummy xf86-video-nouveau xf86-video-i740 xf86-video-amdgpu xf86-video-s3virge xf86-video-ast xf86-video-apm xf86-video-s3 xf86-video-siliconmotion xf86-video-vmware xf86-video-sunleo xf86-video-fbdev xf86-video-ati xf86-video-rendition xf86-video-i128 xf86-video-tdfx xf86-video-chips xf86-video-sis xf86-video-qxl xf86-video-vesa xf86-video-xgixp xf86-video-glint xf86-video-r128 xf86-video-nv xf86-video-openchrome xf86-video-ark xf86-video-savage", shell=True)
    # Gvfs
    apkinstall("gvfs-cdda gvfs-goa gvfs-mtp gvfs-smb gvfs gvfs-afc gvfs-nfs gvfs-archive gvfs-fuse gvfs-gphoto2 gvfs-avahi")
    # Browsers
    apkinstall("firefox")

# Install Desktop Software
if args.desktop == "gnome":
    apkinstall("gnome gnome-apps")
    subprocess.run("rc-update add gdm", shell=True)
elif args.desktop == "kde":
    apkinstall("plasma")
elif args.desktop == "mate":
    apkinstall("desktop-file-utils gtk-engines consolekit gtk-murrine-engine caja caja-extensions marco hicolor-icon-theme")
    apkinstall("libmatemixer mate-session-manager mate-applets mate-control-center mate-sensors-applet libmatekbd mate-desktop mate-panel mate-calc mate-utils mate-tweak mate-icon-theme mate-screensaver mate-menus mate-polkit mate-icon-theme-faenza mate-power-manager mate-common libmateweather mate-indicator-applet mate-terminal mate-settings-daemon mate-system-monitor imagemagick6 mate-notification-daemon mate-backgrounds xfsprogs-extra imagemagick mate-media mesa-demos mate-desktop-environment mate-user-guide mate-themes")
    subprocess.run("rc-update add lightdm", shell=True)
elif args.desktop == "xfce":
    subprocess.run("setup-xorg-base xfce4 xfce4-terminal lightdm-gtk-greeter xfce-polkit xfce4-screensaver consolekit2", shell=True)
    subprocess.run("rc-update add lightdm", shell=True)


# Install software for VMs
if vmstatus == "kvm":
    apkinstall("qemu-guest-agent")
    subprocess.run("rc-update add qemu-guest-agent", shell=True)
if vmstatus == "vbox":
    apkinstall("virtualbox-guest-additions")
    if not args.nogui:
        apkinstall("virtualbox-guest-additions-x11")
if vmstatus == "vmware":
    apkinstall("open-vm-tools open-vm-tools-openrc")
    if not args.nogui:
        apkinstall("open-vm-tools-gtk")
