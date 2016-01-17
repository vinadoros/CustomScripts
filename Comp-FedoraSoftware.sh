#!/bin/bash

# Disable error handlingss
set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR="$SUDO_USER"
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR="$USER"
	else
		export USERNAMEVAR="$(id 1000 -un)"
	fi
	USERGROUP="$(id 1000 -gn)"
	USERHOME="/home/$USERNAMEVAR"
fi

# Set default user environment if none exist.
[ -z $SETDE ] && SETDE=0
[ -z $SETDM ] && SETDM=0

# Set default VM guest variables
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1 
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0

# Set machine architecture
[ -z "$MACHINEARCH" ] && MACHINEARCH=$(uname -m)

# Enable error halting.
set -eu

# Install software
dist_update

# Make user part of wheel group
usermod -aG wheel $USERNAMEVAR

###############################################################################
#########################        Repository Setup     #########################
###############################################################################

# RPM Fusion and fedy
rpm --quiet --query folkswithhats-release || dist_install --nogpgcheck http://folkswithhats.org/repo/$(rpm -E %fedora)/RPMS/noarch/folkswithhats-release-1.0.1-1.fc$(rpm -E %fedora).noarch.rpm
rpm --quiet --query rpmfusion-free-release || dist_install --nogpgcheck http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
rpm --quiet --query rpmfusion-nonfree-release || dist_install --nogpgcheck http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dist_install --nogpgcheck fedy

# Google Chrome (x86_64 only)
[ $MACHINEARCH = "x86_64" ] && dist_install --nogpgcheck https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
[ $MACHINEARCH = "i686" ] && dist_install --nogpgcheck https://dl.google.com/linux/direct/google-chrome-stable_current_i386.rpm

# Virtualbox
wget -O //etc/yum.repos.d/virtualbox.repo http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo

# Russian Fedora
dist_install --nogpgcheck http://mirror.yandex.ru/fedora/russianfedora/russianfedora/free/fedora/russianfedora-free-release-stable.noarch.rpm http://mirror.yandex.ru/fedora/russianfedora/russianfedora/nonfree/fedora/russianfedora-nonfree-release-stable.noarch.rpm

dist_update

# Fedy multimedia codecs
dist_install fedy-multimedia-codecs

# Numix
dnf copr -y enable numix/numix
dnf -y install numix-icon-theme numix-icon-theme-circle numix-gtk-theme

# Syncthing
dnf copr -y enable decathorpe/syncthing
dnf -y install syncthing syncthing-gtk
systemctl enable syncthing@$USERNAMEVAR


# Install openssh
dist_install openssh
systemctl enable sshd

# Install fish
dist_install fish
FISHPATH=$(which fish)
if ! grep -iq "$FISHPATH" /etc/shells; then
	echo "$FISHPATH" | tee -a /etc/shells
fi

# For general desktop
dist_install gparted xdg-utils leafpad
dist_install gnome-disk-utility btrfs-progs
dist_install nbd

# CLI utilities
dist_install curl rsync cabextract lzip p7zip p7zip-plugins unrar nano

# Samba
dist_install samba samba-winbind

# Avahi
dist_install avahi

# Cups-pdf
dist_install cups-pdf

# Multimedia
dist_install gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-vaapi paprefs
dist_install vlc
dist_install audacious audacious-plugins audacious-plugins-freeworld

# GUI
dist_install freetype-freeworld

# Yumex
dist_install yumex yumex-dnf

# Productivity
dist_install thunderbird thunderbird-lightning-gdata
dist_install libreoffice libreoffice-langpack-en

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
	dist_install gnome-tweak-tool gnome-shell-extension-gpaste
    break;;
    
[3]* ) 
    # MATE
    echo "MATE stuff."

    break;;

* ) echo "Not changing desktop environment."
    break;;
esac

