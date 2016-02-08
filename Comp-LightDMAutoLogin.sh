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

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

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
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0
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
	echo "Enabling lightdm autologin for $USERNAMEVAR."
	sed -i 's/#autologin-user=/autologin-user='$USERNAMEVAR'/g' /etc/lightdm/lightdm.conf
	# Enable gnome kerying unlock
	#~ grepadd "auth       optional     pam_gnome_keyring.so" "/etc/pam.d/login"
	#~ grepadd "session    optional     pam_gnome_keyring.so        auto_start" "/etc/pam.d/login"
	#~ grepadd "password	optional	pam_gnome_keyring.so" "/etc/pam.d/passwd"
fi

# Enable listing of users
if [ -f /etc/lightdm/lightdm.conf ]; then
	sed -i 's/#greeter-hide-users=false/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf
fi

# Create filename containing synergyc host.
HOSTFILE="/usr/local/bin/synhost.txt"
if [ ! -f "$HOSTFILE" ]; then
	echo "HostnameHere" >> "$HOSTFILE"
	chmod a+rwx "$HOSTFILE"
	echo "Be sure to change the hostname in $HOSTFILE."
fi

LDSTART="/usr/local/bin/ldstart.sh"
if [ ! -f "$LDSTART" ]; then
	multilinereplace "$LDSTART" <<EOLXYZ
#!/bin/bash
echo "Executing \$0"

# https://wiki.freedesktop.org/www/Software/LightDM/CommonConfiguration/
# https://bazaar.launchpad.net/~lightdm-team/lightdm/trunk/view/head:/data/lightdm.conf

SERVER="\$(<$HOSTFILE)"

# Note: uncomment the below lines when a server has been placed in the above file location.

if type -p synergyc &> /dev/null; then
	echo "Starting Synergy client."
	# synergyc "\$SERVER"
fi

if type -p synergyc &> /dev/null; then
	echo "Starting vnc."
	# x0vncserver -passwordfile $USERHOME/.vnc/passwd &
fi

exit 0
EOLXYZ
	echo "Be sure to uncomment the lines in $LDSTART."
fi

LDSTOP="/usr/local/bin/ldstop.sh"
multilinereplace "$LDSTOP" <<'EOLXYZ'
#!/bin/bash
echo "Executing $0"
if pgrep synergyc; then
	killall synergyc
fi
if pgrep x0vncserver; then
	killall x0vncserver
fi

exit 0
EOLXYZ

# Run startup scripts
if [ -f /etc/lightdm/lightdm.conf ]; then
	# Uncomment lines
	sed -i '/^#display-setup-script=.*/s/^#//g' /etc/lightdm/lightdm.conf
	sed -i '/^#session-setup-script=.*/s/^#//g' /etc/lightdm/lightdm.conf
	# Add startup scripts to session
	sed -i "s@display-setup-script=.*@display-setup-script=$LDSTART@g" /etc/lightdm/lightdm.conf
	sed -i "s@session-setup-script=.*@session-setup-script=$LDSTOP@g" /etc/lightdm/lightdm.conf
fi
