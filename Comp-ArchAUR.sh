#!/bin/bash

# Disable error handling
set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

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

# Set default VM guest variables
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0

# Set machine architecture
[ -z "$MACHINEARCH" ] && MACHINEARCH=$(uname -m)

# Set build folder
BUILDFOLDER="/var/tmp"

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# AUR Install function
aur_install(){
	if [ -z "$1" ]; then
		echo "No paramter passed. Returning."
		return 0;
	else
		AURPKG="$1"
	fi
	echo "Building $AURPKG."
	cd $BUILDFOLDER
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/${AURPKG}.tar.gz -O ./${AURPKG}.tar.gz
	tar zxvf ${AURPKG}.tar.gz
	chmod a+rwx -R ${AURPKG}
	cd ${AURPKG}
	su nobody -s /bin/bash <<'EOL'
		makepkg --noconfirm -s
EOL
	pacman -U --noconfirm ./${AURPKG}-*.pkg.tar.xz
	cd ..
	rm -rf ${AURPKG}/
	rm ${AURPKG}.tar.gz
}

# Ensure base and base-devel are present.
dist_update
pacman -Syu --needed --noconfirm base base-devel

# Allow sudo pacman use without password (for Yaourt)
# Syntax: username ALL=(ALL) NOPASSWD: /usr/bin/pacman
SUDOPACMANCMD="$USERNAMEVAR ALL=(ALL) NOPASSWD: $(type -P pacman)"
if ! grep -iq "^${SUDOPACMANCMD}$" /etc/sudoers; then
	cp /etc/sudoers /etc/sudoers.w
	echo "" >> /etc/sudoers
	echo "# Allow user to run pacman without password (for Yaourt/makepkg)." >> /etc/sudoers
	echo "$SUDOPACMANCMD" >> /etc/sudoers
fi
visudo -c
if [ -f /etc/sudoers.w ]; then
	rm /etc/sudoers.w
fi

# Install apacman (allows installation of packages using root).
# TODO uncomment once license array error is fixed with apacman.
# pacman -S --needed --noconfirm binutils ca-certificates curl fakeroot file grep jshon sed tar wget
# aur_install "apacman"
# dist_install apacman-deps

# Install yaourt.
aur_install "package-query"
aur_install "yaourt"
