#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

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

# Notify if vnc server not present.
[[ ! $(type -P x0vncserver) ]] && echo "Please Install tigervnc. Exiting." && exit 1;

VNCLOCATION="$(which x0vncserver)"
VNCPASSPATH="${USERHOME}/.vnc"
VNCPASS="${VNCPASSPATH}/passwd"
XHOSTLOCATION="$(which xhost)"
SDPATH="/etc/systemd/system"
SDSERVICE="vncxorg@.service"

set -eu

echo "Normal user: $USERNAMEVAR"
echo "VNC Password: $VNCPASS"
echo "Systemd Service: $SDPATH/$SDSERVICE"

echo ""
read -p "Press any key to create service and script."

if [ ! -f "${VNCPASS}" ]; then
	if [ ! -d "${VNCPASSPATH}" ]; then
		mkdir "${VNCPASSPATH}"
		chown $USERNAMEVAR:$USERGROUP "${VNCPASSPATH}"
	fi
	vncpasswd "${VNCPASS}"
	chown $USERNAMEVAR:$USERGROUP "${VNCPASS}"
	chmod a+r "${VNCPASS}"
fi

echo "Creating $SDPATH/$SDSERVICE."
bash -c "cat >$SDPATH/$SDSERVICE" <<EOL
[Unit]
Description=TigerVNC server for connecting to display %i
Requires=graphical.target
After=network.target nss-lookup.target network-online.target graphical.target

[Service]
Type=simple
Environment="DISPLAY=:%i"
ExecStartPre=${XHOSTLOCATION} +localhost
ExecStart=${VNCLOCATION} -display :%i -passwordfile ${USERHOME}/.vnc/passwd
Restart=always
RestartSec=10s
TimeoutStopSec=7s
User=${USERNAMEVAR}

[Install]
WantedBy=graphical.target
EOL
systemctl daemon-reload
echo "Run \"systemctl enable vncxorg@0.service\" to enable vnc xorg client."

