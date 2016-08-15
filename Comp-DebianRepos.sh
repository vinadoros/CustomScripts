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

if [ -z $DEBRELEASE ]; then
	DEBRELEASE=$(lsb_release -sc)
fi

if [ -z "$MACHINEARCH" ]; then
	MACHINEARCH=$(uname -m)
fi

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install Repos.

# Update the system
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y

# Install add-apt-repository command
apt-get install -y software-properties-common dirmngr

# Main, contrib and non-free for normal distro
add-apt-repository main
add-apt-repository contrib
add-apt-repository non-free

# Add Stable updates distro.
if [[ $DEBRELEASE != "sid" && $DEBRELEASE != "unstable" && $DEBRELEASE != "testing" ]] && ! grep -i "$DEBRELEASE-updates main" /etc/apt/sources.list; then
	add-apt-repository "deb http://ftp.us.debian.org/debian $DEBRELEASE-updates main contrib non-free"
fi

# Comment out lines containing httpredir.
sed -i '/httpredir/ s/^#*/#/' /etc/apt/sources.list

# Stable backports distro
if [[ $DEBRELEASE != "sid" && $DEBRELEASE != "unstable" && $DEBRELEASE != "testing" ]] && ! grep -i "$DEBRELEASE-backports main" /etc/apt/sources.list; then
	add-apt-repository "deb http://ftp.us.debian.org/debian $DEBRELEASE-backports main contrib non-free"
fi

# Debian Multimedia
if ! grep -i "deb-multimedia" /etc/apt/sources.list; then
	add-apt-repository "deb http://www.deb-multimedia.org $DEBRELEASE main non-free"
	apt-get update
	apt-get install -y --force-yes deb-multimedia-keyring
	apt-get update
fi

# Backports for deb-multimedia
if [[ $DEBRELEASE != "sid" && $DEBRELEASE != "unstable" && $DEBRELEASE != "testing" ]] && ! grep -i "$DEBRELEASE-backports main" /etc/apt/sources.list; then
	add-apt-repository "deb http://www.deb-multimedia.org $DEBRELEASE-backports main non-free"
fi

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

if [ "${MACHINEARCH}" != "armv7l" ]; then
	# Ubuntuzilla
	if ! grep -i "ubuntuzilla" /etc/apt/sources.list; then
		add-apt-repository "deb http://downloads.sourceforge.net/project/ubuntuzilla/mozilla/apt all main"
		apt-key adv --recv-keys --keyserver keyserver.ubuntu.com C1289A29
		apt-get update
	fi
	# Remove iceweasel
	if dpkg-query -l | grep -iq "iceweasel"; then
		apt-get remove --purge -y iceweasel
	fi
	apt-get install -y firefox-mozilla-build

elif [ "${MACHINEARCH}" = "armv7l" ]; then
	echo "Installing arm specific repos."
fi

# Update repositories
echo "Done adding repositories. Now updating."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
