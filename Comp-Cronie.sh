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

if type -p pacman &> /dev/null; then
	dist_install cronie
	systemctl enable cronie
fi

if type -p apt-get &> /dev/null; then
	dist_install cron anacron
fi

# Anacron configuration
sed -i 's/RANDOM_DELAY=.*$/RANDOM_DELAY=0/g' /etc/anacrontab
sed -i 's/START_HOURS_RANGE=.*$/START_HOURS_RANGE=0-24/g' /etc/anacrontab
sed -i -e 's/1.*\tcron.daily/1\t0\tcron.daily/g' /etc/anacrontab
sed -i -e 's/7.*\tcron.weekly/7\t0\tcron.weekly/g' /etc/anacrontab
sed -i -e 's/@monthly.*\tcron.monthly/@monthly 0\tcron.monthly/g' /etc/anacrontab

grepcheckadd "0 * * * * bash -c \"cd /opt/CustomScripts; git pull\"" "0 \* \* \* \* bash -c \"cd /opt/CustomScripts; git pull\"" "/var/spool/cron/$USERNAMEVAR"
grepcheckadd "@reboot bash -c \"cd /opt/CustomScripts; git pull\"" "@reboot" "/var/spool/cron/$USERNAMEVAR"
su - $USERNAMEVAR -c "crontab /var/spool/cron/$USERNAMEVAR"

if type -p pacman &> /dev/null; then
	echo "Adding pacman statements to cron."
	multilinereplace "/etc/cron.weekly/pacclean" <<'EOL'
#!/bin/bash
pacman -Sc --noconfirm
pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm
EOL
fi
