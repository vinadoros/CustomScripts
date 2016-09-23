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
USERHOME=os.path.expanduser("~")
print("Username is:",USERNAMEVAR)
print("Group Name is:",USERGROUP)

# Set up Fedora Repos
REPOSCRIPT="""
#!/bin/bash

# Repository options: https://wiki.centos.org/AdditionalResources/Repositories

# EPEL
yum install -y epel-release

# Centos Plus
yum-config-manager --enable centosplus

# Centos Fasttrack
yum-config-manager --enable CentOS-fasttrack

# Webtatic
yum install -y http://repo.webtatic.com/yum/el7/webtatic-release.rpm

# Software Collections
# https://www.softwarecollections.org
yum install -y centos-release-scl

# EL Repo
# https://elrepo.org
yum install -y http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum-config-manager --enable elrepo-extras elrepo-kernel

yum update -y

"""
subprocess.run(REPOSCRIPT, shell=True)

# Install Fedora Software
SOFTWARESCRIPT="""
#!/bin/bash

# Install cli tools
yum install -y fish tmux iotop rsync p7zip p7zip-plugins zip unzip xdg-utils util-linux-user

# Management tools
# yum install -y yumex gparted

# Install browsers
# yum install -y chromium @firefox freshplayerplugin

# Samba
yum install -y samba samba-winbind

# NTP configuration
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Cups
# yum install -y cups-pdf

# Wine
# yum install -y wine playonlinux

# Desktop Specific code
# yum install -y gnome-terminal-nautilus gnome-tweak-tool dconf-editor
# yum install -y gnome-shell-extension-gpaste
"""
subprocess.run(SOFTWARESCRIPT, shell=True)
