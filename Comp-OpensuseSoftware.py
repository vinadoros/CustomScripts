#!/usr/bin/env python3

# Python includes.
import argparse
import grp
import os
import pwd
import subprocess
import sys

print("Running {0}".format(__file__))

# Get arguments
parser = argparse.ArgumentParser(description='Install OpenSUSE Software.')
parser.add_argument("-d", "--desktop", dest="desktop", type=int, help='Desktop Environment', default="0")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:",args.desktop)

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
USERHOME=os.path.expanduser("~")
print("Username is:",USERNAMEVAR)
print("Group Name is:",USERGROUP)

# Get VM State
# Detect QEMU
with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
    DATA=VAR.read().replace('\n', '')
    if "QEMU" in DATA:
        QEMUGUEST=True
    else:
        QEMUGUEST=False
# Detect Virtualbox
with open('/sys/devices/virtual/dmi/id/product_name', 'r') as VAR:
    DATA=VAR.read().replace('\n', '')
    if "VirtualBox" in DATA:
        VBOXGUEST=True
    else:
     	VBOXGUEST=False
# Detect VMWare
with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
    DATA=VAR.read().replace('\n', '')
    if "VMware" in DATA:
        VMWGUEST=True
    else:
     	VMWGUEST=False

# Set up OpenSUSE Repos
REPOSCRIPT="""#!/bin/bash

# Packman
zypper ar -f -n packman http://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman

# Adobe Flash
# https://en.opensuse.org/Adobe_Flash_Player
zypper ar --check --refresh http://linuxdownload.adobe.com/linux/x86_64/ adobe
rpm -ivh http://linuxdownload.adobe.com/adobe-release/adobe-release-x86_64-1.0-1.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-adobe-linux

# Import all gpg keys
zypper --non-interactive --gpg-auto-import-keys refresh

"""
subprocess.run(REPOSCRIPT, shell=True)

# Install Fedora Software
SOFTWARESCRIPT="""
# Install cli tools
zypper install -y fish nano tmux iotop rsync p7zip zip unzip xdg-utils xdg-user-dirs

# Management tools
zypper install -y gparted

# Install browsers
zypper install -y chromium MozillaFirefox freshplayerplugin
# Adobe Flash
zypper in -y flash-plugin flash-player-ppapi

# Samba
zypper install -y samba samba-client samba-winbind

# NTP configuration
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Cups
zypper install -y cups-pdf

# Wine
zypper install -y wine wine-32bit

# Multimedia
zypper install -y pavucontrol paprefs vlc smplayer

# terminator
zypper install -y terminator

# Change to NetworkManager
systemctl disable wicked
systemctl enable NetworkManager
"""
# Install software for VMs
if QEMUGUEST is True:
    SOFTWARESCRIPT+="""
# Guest Agent
zypper install -y spice-vdagent qemu-guest-agent
"""
if VBOXGUEST is True:
    SOFTWARESCRIPT+="""
"""
if VMWGUEST is True:
    SOFTWARESCRIPT+="""
# VM tools
zypper install -y open-vm-tools open-vm-tools-desktop
"""
subprocess.run(SOFTWARESCRIPT, shell=True)

# Install Desktop Software
if args.desktop is 1:
    DESKTOPSCRIPT="""
# Gnome
zypper install -y -t pattern gnome_admin gnome_basis gnome_basis_opt gnome_imaging gnome_utilities gnome_laptop gnome_yast sw_management_gnome
zypper install -y eog gnome-extension-terminal dconf-editor
zypper install -y gdm
zypper install -y gnome-shell-extension-gpaste
# Change display manager to gdm
sed -i 's/DISPLAYMANAGER=.*$/DISPLAYMANAGER="gdm"/g' /etc/sysconfig/displaymanager
"""
elif args.desktop is 3:
    DESKTOPSCRIPT="""
# MATE
zypper install -y -t pattern mate_basis mate_admin mate_laptop mate_utilities
# Applications
zypper install -y dconf-editor
# Display Manager
zypper install -y lightdm lightdm-gtk-greeter
# Change display manager to lightdm
sed -i 's/DISPLAYMANAGER=.*$/DISPLAYMANAGER="lightdm"/g' /etc/sysconfig/displaymanager
"""

DESKTOPSCRIPT+="""
systemctl set-default graphical.target
"""
subprocess.run(DESKTOPSCRIPT, shell=True)
