#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi


# Install google-chrome
MACHINEARCH=$(uname -m)
if ! dpkg-query -l | grep -iq "google-chrome"; then
	if [ "${MACHINEARCH}" = "x86_64" ]; then
		wget -P ~/ https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
	else
		wget -P ~/ https://dl.google.com/linux/direct/google-chrome-stable_current_i386.deb
	fi
	gdebi -n ~/google-chrome-*.deb
	rm ~/google-chrome-*.deb
fi
