#!/bin/bash

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

set -eu

dist_install systemd-cron
systemctl enable cron.target
chmod a+rwx /var/spool/cron

grepcheckadd "0 * * * * bash -c \"cd /opt/CustomScripts; git pull\"" "CustomScripts" "/var/spool/cron/$USERNAMEVAR"
su - $USERNAMEVAR -c "crontab /var/spool/cron/$USERNAMEVAR"

if type -p pacman &> /dev/null; then
	echo "Adding pacman statements to cron."
	grepcheckadd "0 0 * * 6 \"pacman -Sc --noconfirm\"" "pacman -Sc --noconfirm" "/var/spool/cron/root"
	grepcheckadd "0 0 * * 0 \"pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm\"" "pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm" "/var/spool/cron/root"
	crontab /var/spool/cron/root
fi

#~ cd /run/systemd/generator
