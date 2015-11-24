#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handling
set +eu

BOXPATH="/media/Box"
BOXSHORTHAND="dav.box.com"

# Source file which contains box username and password.
# Private variable file.
PRIVATEVARS="/usr/local/bin/privateconfig.sh"
if [ -f $PRIVATEVARS ]; then
	source "$PRIVATEVARS"
fi

if [[ -z $BOXUSERNAME || -z $BOXPASSWORD ]]; then
	echo "Error, no box username and password specified. Skipping Box Setup."
else

# Set user folders if they don't exist.
if [ -z "$USERNAMEVAR" ]; then
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

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

if [[ ! $(type -P mount.davfs) ]]; then
	echo "Installing davfs2.:"
	if [[ $(type -P pacman) ]]; then
		pacman -S --needed --noconfirm davfs2
	elif [[ $(type -P apt-get) ]]; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y davfs2
		usermod -aG disk,davfs2 $USERNAMEVAR
	elif [[ $(type -P dnf) ]]; then
		dnf install -y davfs2
	fi
fi

if [[ ! $(type -P mount.davfs) ]]; then
	echo "You don't have davfs. Exiting."
	exit 1;
fi

if [ ! -d $BOXPATH ]; then
	echo "Creating $BOXPATH folder."
	sudo mkdir -p $BOXPATH
	sudo chown -R $USERNAMEVAR:$USERGROUP $BOXPATH
	sudo chmod a+rwx "$(dirname $BOXPATH)"
	sudo chmod a+rwx $BOXPATH
fi

# Delete existing fstab entry for box.
#~ if grep -iq "$BOXSHORTHAND" /etc/fstab; then
	#~ sed -i '/$BOXSHORTHAND/d' /etc/fstab
#~ fi

# Delete existing secrets file
if [ -f /etc/davfs2/secrets ]; then
	rm /etc/davfs2/secrets
	touch /etc/davfs2/secrets
	chmod 600 /etc/davfs2/secrets
fi


if ! grep -iq "$BOXSHORTHAND" /etc/fstab; then
	echo "Editing fstab for $BOXSHORTHAND"
	if [ ! -z "$(tail -1 /etc/fstab)" ]; then echo "" >> /etc/fstab ; fi
	if ls -l /sbin/init | grep -iq "systemd" ; then
		echo "https://dav.box.com/dav $BOXPATH davfs rw,exec,uid=$USERNAMEVAR,gid=$USERGROUP,noauto,x-systemd.automount 0 0" >> /etc/fstab
	else
		echo "https://dav.box.com/dav $BOXPATH davfs rw,exec,uid=$USERNAMEVAR,gid=$USERGROUP,nofail,_netdev 0 0" >> /etc/fstab
	fi
fi

# Add secret to global davfs2 secrets.
if ! grep -iq "$BOXSHORTHAND" /etc/davfs2/secrets; then
	echo "Adding $BOXSHORTHAND secrets files."
	echo "https://dav.box.com/dav $BOXUSERNAME $BOXPASSWORD" >> /etc/davfs2/secrets
fi


if ! grep -iq "use_locks 0" /etc/davfs2/davfs2.conf; then
	echo "Editing davfs2.conf for locks."
	echo "use_locks 0" >> /etc/davfs2/davfs2.conf
fi

if mount | grep -iq "$BOXSHORTHAND"; then
	echo "Box.com share already mounted. Unmounting."
	umount "$BOXPATH"
fi
echo "Mounting Box Share."
mount "$BOXPATH"

echo "All done, Box share should be mounted."

fi
