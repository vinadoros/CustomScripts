#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

function usage()
{
cat <<EOF
Usage: sudo $0 [Display number to use, i.e. 0]

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
	DISPLAYNUM="0"
else
	DISPLAYNUM="$1"
	# Convert displaynum to only numbers
	DISPLAYNUM="${DISPLAYNUM//[^0-9_]/}"
fi


# Install synergy if not present.
[[ ! $(type -P synergyc) ]] && echo "Please Install synergy. Exiting." && exit 1;

SYNERGYLOCATION="$(which synergyc)"
XHOSTLOCATION="$(which xhost)"
SDPATH="/etc/systemd/system"
SDSERVICE="synergyc@.service"

set -eu

echo "Normal user: $USERNAMEVAR"
echo "Systemd Service: $SDPATH/$SDSERVICE"
echo "Display: $DISPLAYNUM"

echo ""
read -p "Press any key to create service and script."

echo "Creating $SDPATH/$SDSERVICE."
bash -c "cat >$SDPATH/$SDSERVICE" <<EOL
[Unit]
Description=Synergy Client for connecting to %i
Requires=graphical.target
After=network.target nss-lookup.target network-online.target graphical.target

[Service]
Type=simple
Environment="DISPLAY=:${DISPLAYNUM}"
ExecStartPre=${XHOSTLOCATION} +localhost
ExecStart=${SYNERGYLOCATION} -d WARNING -1 -f %i
Restart=always
RestartSec=3s
TimeoutStopSec=7s
User=${USERNAMEVAR}

[Install]
WantedBy=graphical.target
EOL
systemctl daemon-reload
echo "Run \"systemctl enable synergyc@servername.service\" to enable synergy client."

