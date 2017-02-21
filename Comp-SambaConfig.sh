#!/bin/bash

# Disable error handling.
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

# Samba password location
SAMBAFILEPASS="/var/tmp/sambapass.txt"
if [ -f $SAMBAFILEPASS ]; then
	SMBPASS="\$(<$SAMBAFILEPASS)"
fi

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

if [ ! -f /etc/samba/smb.conf ]; then
	touch /etc/samba/smb.conf
fi

# Set samba password if it doesn't exist.
if ! pdbedit -L | grep -iq "$USERNAMEVAR" ; then
	if [ -z $SMBPASS ]; then
		echo "Enter an SMB password for $USERNAMEVAR:"
		until pdbedit -a -u $USERNAMEVAR
			do echo "Try again in 2 seconds."
			sleep 2
			echo "Enter an SMB password for the current user:"
		done
	else
		echo -e "${SMBPASS}\n${SMBPASS}" | pdbedit -a -u $USERNAMEVAR -t
	fi
else
	echo "Skipping SMB password."
fi

# Enable error halting.
set -eu

# Add samba shares.

sambaconfigadd () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		MNTFOLDER="$1"
	fi

	for FLD in "${MNTFOLDER}"/*/; do
		echo "Detected folder $FLD"
		FLDBASE=$(basename "$FLD")

		if [ -d "$FLD" ] && ! grep -iq "\[${FLDBASE}\]" /etc/samba/smb.conf; then
			echo "Adding ${FLDBASE} share for ${FLD} to smb.conf."
			bash -c "cat >>/etc/samba/smb.conf" <<EOL

[${FLDBASE}]
	force user = $USERNAMEVAR
	write list = $USERNAMEVAR
	writeable = yes
	force group = $USERGROUP
	valid users = $USERNAMEVAR
	path = ${FLD}
	delete readonly = yes

EOL
		fi

	done
}

if ! grep -iq "\[root\]" /etc/samba/smb.conf; then
	echo "Adding root share for samba to smb.conf."
	bash -c "cat >>/etc/samba/smb.conf" <<EOL

[root]
	force user = $USERNAMEVAR
	write list = $USERNAMEVAR
	writeable = yes
	force group = $USERGROUP
	valid users = $USERNAMEVAR
	path = /
	delete readonly = yes

EOL
fi

if [ -d $USERHOME ] && ! grep -iq "\[Home\]" /etc/samba/smb.conf; then
	echo "Adding Home share for samba to smb.conf."
	bash -c "cat >>/etc/samba/smb.conf" <<EOL

[Home]
	force user = $USERNAMEVAR
	write list = $USERNAMEVAR
	writeable = yes
	force group = $USERGROUP
	valid users = $USERNAMEVAR
	path = $USERHOME
	delete readonly = yes

EOL
fi

sambaconfigadd "/mnt"


# Modify nsswitch.conf
if [ -f /etc/nsswitch.conf ] && ! grep -iq "^hosts:.*mdns_minimal" /etc/nsswitch.conf; then
	echo "Adding mdns_minimal to nsswitch.conf."
	sed -i '/^hosts:/ s=files=files mdns_minimal=' /etc/nsswitch.conf
fi

if [ -f /etc/avahi/avahi-daemon.conf ]; then
	echo "Modifying avahi-daemon.conf."
	sed -i 's/^use-ipv6=.*$/use-ipv6=yes/' /etc/avahi/avahi-daemon.conf
	sed -i 's/^publish-workstation=.*$/publish-workstation=yes/' /etc/avahi/avahi-daemon.conf
fi
