#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

[ -z $DEBRELEASE ] && DEBRELEASE=$(lsb_release -sc)
[ -z "$MACHINEARCH" ] && MACHINEARCH=$(uname -m)

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
	wget -qO- https://syncthing.net/release-key.txt | apt-key add -

	# Add the "release" channel to your APT sources:
	echo "deb http://apt.syncthing.net/ syncthing release" | tee /etc/apt/sources.list.d/syncthing-release.list

	# Update and install syncthing:
	apt-get update
	apt-get install -y syncthing syncthing-inotify
fi

# Getdeb
# add-apt-repository "deb http://mirrors.dotsrc.org/getdeb/ubuntu ${DEBRELEASE}-getdeb apps games"
# apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A8A515F046D7E7CF

# Add timeouts for repository connections
cat >"/etc/apt/apt.conf.d/99timeout" <<'EOL'
Acquire::http::Timeout "5";
Acquire::https::Timeout "5";
Acquire::ftp::Timeout "5";
EOL

# Update repositories
echo "Done adding repositories. Now updating."
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
