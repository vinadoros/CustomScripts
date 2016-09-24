#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
	USERGROUP=$(id 1000 -gn)
	USERHOME=/home/$USERNAMEVAR
fi

##### Centos Repositories #####

# Repository options: https://wiki.centos.org/AdditionalResources/Repositories

# EPEL
yum install -y epel-release

# Centos Plus
yum-config-manager --enable centosplus

# Centos Fasttrack
yum-config-manager --enable fasttrack

# IUS
# https://ius.io/
yum install -y https://centos7.iuscommunity.org/ius-release.rpm

# Software Collections
# https://www.softwarecollections.org
yum install -y centos-release-scl

# EL Repo
# https://elrepo.org
yum install -y http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum-config-manager --enable elrepo-extras elrepo-kernel

# Chrome Repository
yum install -y https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm

yum update -y

##### Centos Software #####

# Install cli tools
yum install -y python34 fish tmux iotop rsync p7zip p7zip-plugins zip unzip xdg-utils

# Management tools
yum install -y yumex gparted

# Install browsers
yum install -y firefox

# Samba
yum install -y samba samba-winbind

# NTP configuration
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Cups
yum install -y cups-pdf

# Wine
yum install -y wine

# Desktop Specific code
yum install -y gnome-terminal-nautilus gnome-tweak-tool dconf-editor
yum install -y gnome-shell-extension-gpaste gnome-shell-extension-dash-to-dock
