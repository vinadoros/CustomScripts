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

# Set default user environment if none exist.
if [ -z $SETDE ]; then
	SETDE=3
fi

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install software

dnf update -y

# Make user part of wheel group
usermod -aG wheel $USERNAMEVAR

# Install openssh
dnf install -y openssh

# Install fish
dnf install -y fish
FISHPATH=$(which fish)
if ! grep -iq "$FISHPATH" /etc/shells; then
	echo "$FISHPATH" | tee -a /etc/shells
fi

# For general desktop
dnf install -y gparted xdg-utils leafpad
dnf install -y gnome-disk-utility btrfs-progs
dnf install -y nbd

# CLI utilities
dnf install -y curl rsync

# Samba
dnf install -y samba samba-winbind

# Avahi
dnf install -y avahi

# Cups-pdf
dnf install -y cups-pdf

# Extra repos
rpm --quiet --query rpmfusion-free-release || dnf -y --nogpgcheck install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
rpm --quiet --query rpmfusion-nonfree-release || dnf -y --nogpgcheck install http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf update -y

# Multimedia
dnf install -y gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-vaapi vlc

###############################################################################
######################        Desktop Environments      #######################
###############################################################################
# Case for SETDE variable. 0=do nothing, 1=KDE, 2=cinnamon
case $SETDE in
[1]* ) 
    # KDE
    echo "KDE stuff."
    
    break;;

[2]* ) 
    # GNOME
    echo "GNOME stuff."

    break;;
    
[3]* ) 
    # MATE
    echo "MATE stuff."

    break;;

* ) echo "Not changing desktop environment."
    break;;
esac

