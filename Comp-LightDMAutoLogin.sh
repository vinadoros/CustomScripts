#!/bin/bash

set +eu

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

# Set default VM guest variables
[ -z $VBOXGUEST ] && VBOXGUEST=0
[ -z $VMWGUEST  ] && VMWGUEST=0
[ -z $QEMUGUEST ] && QEMUGUEST=0
[ -z $LIGHTDMAUTO ] && LIGHTDMAUTO=0

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi


# Set-up lightdm autologin
if [ -f /etc/systemd/system/display-manager.service ] && ls -la /etc/systemd/system/display-manager.service | grep -iq "lightdm"; then
	if ! grep -i "^autologin" /etc/group; then
		groupadd autologin
	fi
	gpasswd -a $USERNAMEVAR autologin
fi

# Enable lightdm autologin for virtual machines.
if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 || $LIGHTDMAUTO = 1 ]] && [ -f /etc/lightdm/lightdm.conf ]; then
	sed -i 's/#autologin-user=/autologin-user='$USERNAMEVAR'/g' /etc/lightdm/lightdm.conf
fi

# Enable listing of users
if [ -f /etc/lightdm/lightdm.conf ]; then
	sed -i 's/#greeter-hide-users=false/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf
fi
