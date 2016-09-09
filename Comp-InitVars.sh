#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

set +eu

# Set normal user.
if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
	export USERNAMEVAR=$SUDO_USER
elif [ "$USER" != "root" ]; then
	export USERNAMEVAR=$USER
else
	export USERNAMEVAR=$(id 1000 -un)
fi

export MACHINEARCH=$(uname -m)
export USERGROUP=$(id $USERNAMEVAR -gn)
export USERHOME=/home/$USERNAMEVAR
export SAMBAFILEPASS="/var/tmp/sambapass.txt"
if [ ! -d $USERHOME ]; then
	echo "User home not found. Exiting."
	exit 1;
fi

echo "Username is $USERNAMEVAR"
echo "User home is $USERHOME"
echo "Machinearch is ${MACHINEARCH}"

# Enable installing to guest. Set to 0 if physical machine. When set to 0, will instead install virtualbox as host.
if grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name"; then
	export VBOXGUEST=1
	echo "Virtualbox Detected"
else
	export VBOXGUEST=0
	echo "Virtualbox not Detected"
fi
if grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor"; then
	export QEMUGUEST=1
	echo "QEMU Detected"
else
	export QEMUGUEST=0
	echo "QEMU not Detected"
fi
if grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name"; then
	export VMWGUEST=1
	echo "VMWare Detected"
else
	export VMWGUEST=0
	echo "VMWare not Detected"
fi

checksambapass () {
	if [ -f $SAMBAFILEPASS ]; then
		SMBPASSWORD="\$(<$SAMBAFILEPASS)"
		SMBPASSWORD2="\$(<$SAMBAFILEPASS)"
	elif [ ! -z "$SMBPASSWORD" ]; then
		SMBPASSWORD2="$SMBPASSWORD"
	fi
}

sambapass () {
	echo "Input a samba password: "
	read -s SMBPASSWORD
	echo "Please confirm password: "
	read -s SMBPASSWORD2
}

checksambapass
if [ -z "$SMBPASSWORD" ]; then
	sambapass
fi
while [[ "$SMBPASSWORD" != "$SMBPASSWORD2" ||  -z "$SMBPASSWORD" ]]; do
	echo "Passwords do not match."
	sambapass
done
SMBPASS="${SMBPASSWORD}"
echo -n "${SMBPASSWORD}" >> "$SAMBAFILEPASS"
