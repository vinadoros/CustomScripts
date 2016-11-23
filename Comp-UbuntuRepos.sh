#!/bin/bash

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

if [ -z $DEBRELEASE ]; then
	DEBRELEASE=$(lsb_release -sc)
fi

if [ -z "$MACHINEARCH" ]; then
	MACHINEARCH=$(uname -m)
fi

UBUNTUURL="http://archive.ubuntu.com/ubuntu/"
UBUNTUARMURL="http://ports.ubuntu.com/ubuntu-ports/"

if [ ${MACHINEARCH} = "armhf" ]; then
	URL=${UBUNTUARMURL}
else
	URL=${UBUNTUURL}
fi

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install Repos.

# Install add-apt-repository command
apt-get update
apt-get install -y software-properties-common apt-transport-https

# Update the system
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

# Main, Restricted, universe, and multiverse for Ubuntu.
add-apt-repository main
add-apt-repository restricted
add-apt-repository universe
add-apt-repository multiverse

# Updates repo
if ! grep -i "${DEBRELEASE}-updates main" /etc/apt/sources.list; then
	add-apt-repository "deb ${URL} ${DEBRELEASE}-updates main restricted universe multiverse"
fi

# Security repo
if ! grep -i "${DEBRELEASE}-security main" /etc/apt/sources.list; then
	add-apt-repository "deb ${URL} ${DEBRELEASE}-security main restricted universe multiverse"
fi

# Backports repo
if ! grep -i "${DEBRELEASE}-backports main" /etc/apt/sources.list; then
	add-apt-repository "deb ${URL} ${DEBRELEASE}-backports main restricted universe multiverse"
fi

# Comment out lines containing httpredir.
sed -i '/httpredir/ s/^#*/#/' /etc/apt/sources.list

# Syncthing
if [ ! -f /etc/apt/sources.list.d/syncthing-release.list ]; then

	#curl -s https://syncthing.net/release-key.txt | apt-key add -
	wget -qO- https://syncthing.net/release-key.txt | apt-key add -

	# Add the "release" channel to your APT sources:
	echo "deb http://apt.syncthing.net/ syncthing release" | tee /etc/apt/sources.list.d/syncthing-release.list

	# Update and install syncthing:
	apt-get update
	apt-get install -y syncthing
fi

# Update repositories
echo "Done adding repositories. Now updating."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
