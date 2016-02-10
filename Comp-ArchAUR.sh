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
	su $USERNAMEVAR -s /bin/bash <<'EOL'
		makepkg --noconfirm -A -s
EOL
	pacman -U --noconfirm ./${AURPKG}-*.pkg.tar.xz
	cd ..
	rm -rf ${AURPKG}/
	rm ${AURPKG}.tar.gz
}

# Ensure base and base-devel are present.
pacman -Syu --needed --noconfirm base base-devel

# Allow sudo pacman use without password (for Yaourt)
# Syntax: username ALL=(ALL) NOPASSWD: /usr/bin/pacman
sudoersmultilineadd "$USERNAMEVAR ALL=(ALL) NOPASSWD: $(type -P pacman)" <<EOL

# Allow user to run pacman without password (for Yaourt/makepkg).
$USERNAMEVAR ALL=(ALL) NOPASSWD: $(type -P pacman)
$USERNAMEVAR ALL=(ALL) NOPASSWD: $(type -P cp)
EOL

# Set up GPG.
# Make sure .gnupg folder exists for root
if [ ! -d /root/.gnupg ]; then
	echo "Creating /root/.gnupg folder."
	mkdir -p /root/.gnupg
else
	echo "Skipping /root/.gnupg creation, folder exists."
fi

# Set gnupg to auto-retrive keys. This is needed for some aur packages.
su $USERNAMEVAR -s /bin/bash <<'EOL'
	# First create the gnupg database if it doesn't exist.
	if [ ! -d ~/.gnupg ]; then
		gpg --list-keys
	fi
	# Have gnupg autoretrieve keys.
	if [ -f ~/.gnupg/gpg.conf ]; then
		sed -i 's/#keyserver-options auto-key-retrieve/keyserver-options auto-key-retrieve/g' ~/.gnupg/gpg.conf
	fi
EOL

# Install yaourt.
aur_install "package-query"
aur_install "yaourt"

# Yaourt config
# URL: https://www.archlinux.fr/man/yaourtrc.5.html
# Place all built packages in pacman cache folder.
grepadd "EXPORT=2" "/etc/yaourtrc"

# Install pacaur.

if [ "$MACHINEARCH" = "armv7l" ]; then
	PATH="$PATH:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl"
fi
pacman -S --needed --noconfirm curl openssl pacman yajl perl expac git sudo
aur_install "cower"
aur_install "pacaur"

# Pacaur config
# URLS:
# https://github.com/rmarquis/pacaur/blob/master/config
# https://github.com/rmarquis/pacaur/issues/399
# https://github.com/rmarquis/pacaur/issues/304
# Place all built packages in pacman cache folder.
grepadd "PKGDEST=/var/cache/pacman/pkg" "/etc/xdg/pacaur/config"
# Ignore arch when building packages.
grepadd 'makeopts+=("--ignorearch")' "/etc/xdg/pacaur/config"
