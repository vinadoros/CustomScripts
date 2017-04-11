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
parser = argparse.ArgumentParser(description='Install Fedora Software.')
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
USERHOME=os.path.expanduser("~{0}".format(USERNAMEVAR))
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

# Set up Fedora Repos
REPOSCRIPT="""
#!/bin/bash

# RPM Fusion
dnf install -y http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf update -y

"""
subprocess.run(REPOSCRIPT, shell=True)

# Install Fedora Software
SOFTWARESCRIPT="""
# Install cli tools
dnf install -y fish nano tmux iotop rsync p7zip p7zip-plugins zip unzip xdg-utils xdg-user-dirs util-linux-user

# Install GUI packages
dnf install -y @fonts @base-x @networkmanager-submodules avahi
dnf install -y powerline-fonts google-roboto-fonts google-roboto-mono-fonts

# Management tools
dnf install -y yumex-dnf gparted

# Install browsers
dnf install -y chromium @firefox freshplayerplugin

# Samba
dnf install -y samba

# NTP configuration
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Cups
dnf install -y cups-pdf

# Wine
dnf install -y wine playonlinux

# terminator
# dnf install -y terminator
"""
# Install software for VMs
if QEMUGUEST is True:
    SOFTWARESCRIPT+="""
# Guest Agent
dnf install -y spice-vdagent qemu-guest-agent
"""
if VBOXGUEST is True:
    SOFTWARESCRIPT+="""
"""
if VMWGUEST is True:
    SOFTWARESCRIPT+="""
# VM tools
dnf install -y open-vm-tools open-vm-tools-desktop
"""
subprocess.run(SOFTWARESCRIPT, shell=True)

# Install Desktop Software
if args.desktop is 1:
    DESKTOPSCRIPT="""
# Gnome
dnf install -y @workstation-product @gnome-desktop
# Some Gnome Extensions
dnf install -y gnome-terminal-nautilus gnome-tweak-tool dconf-editor
dnf install -y gnome-shell-extension-gpaste
"""
elif args.desktop is 3:
    DESKTOPSCRIPT="""
# MATE
dnf install -y @mate-desktop @mate-applications
# Applications
dnf install -y dconf-editor
"""

DESKTOPSCRIPT+="""
systemctl set-default graphical.target
"""
subprocess.run(DESKTOPSCRIPT, shell=True)
