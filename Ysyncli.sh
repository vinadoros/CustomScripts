#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

function usage()
{
cat <<EOF
Usage: sudo $0 [Name or IP of server] [Display number to use, i.e. 0]

EOF
exit 1;
}

if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
	USERNAMEVAR="$SUDO_USER"
elif [ "$USER" != "root" ]; then
	USERNAMEVAR="$USER"
else
	USERNAMEVAR="$(id 1000 -un)"
fi

if [ -z "$1" ]; then
	echo "Error, no server selected. Exiting."
	usage
else
	SERVER="$1"
fi

if [ -z "$2" ]; then
	DISPLAYNUM="0"
else
	DISPLAYNUM="$2"
	# Convert displaynum to only numbers
	DISPLAYNUM="${DISPLAYNUM//[^0-9_]/}"
fi


# Install synergy if not present.
#~ [[ ! $(type -P synergyc) && $(type -P pacman) ]] && pacman -Syu --needed --noconfirm synergy

# Remove all spaces, and truncate everything after a dash or dot.
BASESERVER="${SERVER//[[:blank:]]/}"
BASESERVER="${BASESERVER%%[.-]*}"

SYNERGYLOCATION="$(which synergyc)"
XHOSTLOCATION="$(which xhost)"
SDPATH="/etc/systemd/system"
SDSERVICE="synergyc-${BASESERVER}.service"

set -eu

echo "Normal user: $USERNAMEVAR"
echo "Systemd Service: $SDPATH/$SDSERVICE"
echo "Server Name: $SERVER"
echo "Display: $DISPLAYNUM"

echo ""
read -p "Press any key to create service and script."

echo "Creating $SDPATH/$SDSERVICE."
bash -c "cat >$SDPATH/$SDSERVICE" <<EOL
[Unit]
Description=Synergy Client for connecting to ${SERVER}
Requires=graphical.target
After=network.target nss-lookup.target network-online.target graphical.target

[Service]
Type=simple
Environment="DISPLAY=:${DISPLAYNUM}"
ExecStartPre=${XHOSTLOCATION} +localhost
ExecStart=${SYNERGYLOCATION} -d WARNING -1 -f ${SERVER}
Restart=always
RestartSec=3s
TimeoutStopSec=7s
User=${USERNAMEVAR}

[Install]
WantedBy=graphical.target
EOL
systemctl daemon-reload
systemctl enable "$SDSERVICE"

