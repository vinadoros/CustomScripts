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
		export USERNAMEVAR="$SUDO_USER"
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR="$USER"
	else
		export USERNAMEVAR="$(id 1000 -un)"
	fi
	USERGROUP="$(id 1000 -gn)"
	USERHOME="/home/$USERNAMEVAR"
fi

set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# cron script to clean pacman cache weekly
if type -p fcrontab &> /dev/null; then
	grepcheckadd "&b 0 0 * * 6 \"pacman -Sc --noconfirm\"" "pacman -Sc --noconfirm" "/var/spool/fcron/root.orig"
	grepcheckadd "&b 0 0 * * 0 \"pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm\"" "pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm" "/var/spool/fcron/root.orig"
	fcrontab -z
fi
if [ -d "/etc/cron.weekly" ]; then
	echo "Adding pacman statements to cron."
	multilinereplace "/etc/cron.weekly/pacclean" <<'EOL'
#!/bin/bash
echo "Executing $0"
echo "Waiting for pacman lock."
while [ -f /var/lib/pacman/db.lck ]; do
	sleep 10
done
pacman -Sc --noconfirm
pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm
EOL
fi
