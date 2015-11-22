#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

#~ CLIENTNAMES="homeserver"

function usage()
{
cat <<EOF
Usage: sudo $0 [Name or IP of clients in parenthesis delimited by a space] [Display number to use, i.e. 0]

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
USERHOME=/home/$USERNAMEVAR

if [[ -z "$1" && -z "$CLIENTNAMES" ]]; then
	echo "Error, no clients selected. Exiting."
	usage
elif [ -z "$CLIENTNAMES" ]; then
	CLIENTNAMES="$1"
fi

if [ -z "$2" ]; then
	DISPLAYNUM="0"
else
	DISPLAYNUM="$2"
	# Convert displaynum to only numbers
	DISPLAYNUM="${DISPLAYNUM//[^0-9_]/}"
fi


# Install synergy if not present.
#~ [[ ! $(type -P synergys) && $(type -P pacman) ]] && pacman -Syu --needed --noconfirm synergy

# Remove all spaces, and truncate everything after a dash or dot.
#~ BASESERVER="${SERVER//[[:blank:]]/}"
#~ BASESERVER="${BASESERVER%%[.-]*}"

SYNERGYLOCATION="$(which synergys)"
XHOSTLOCATION="$(which xhost)"
SDPATH="/etc/systemd/system"
SDSERVICE="synergyserver.service"
SYNWAKESCRIPT="/usr/local/bin/synwake"

for D in $CLIENTNAMES
do
	NCCMD="${NCCMD}\nnc -vz \"$D\" 64777"
done

set -eu

echo "Normal user: $USERNAMEVAR"
echo "Systemd Service: $SDPATH/$SDSERVICE"
echo "Display: $DISPLAYNUM"
echo "Client Names: $CLIENTNAMES"
echo -e "NC cmd: $NCCMD"

echo ""
read -p "Press any key to create service and script."



#~ echo "Creating $SYNWAKESCRIPT"
#~ bash -c "cat >$SYNWAKESCRIPT" <<EOL
#~ #!/bin/bash
#~ set -eu

#~ $(echo -e $NCCMD)

#~ EOL
#~ chmod a+rwx "$SYNWAKESCRIPT"

#~ echo "Creating $SDPATH/$SDSERVICE."
#~ bash -c "cat >$SDPATH/$SDSERVICE" <<EOL
#~ [Unit]
#~ Description=Synergy Server
#~ Requires=graphical.target
#~ After=network.target nss-lookup.target network-online.target graphical.target

#~ [Service]
#~ Type=simple
#~ Environment="DISPLAY=:${DISPLAYNUM}"
#~ ExecStartPre=${XHOSTLOCATION} +localhost
#~ ExecStartPost=$SYNWAKESCRIPT
#~ ExecStart=${SYNERGYLOCATION} -d WARNING -1 -f -c $USERHOME/.config/Synergy/Synergy.conf
#~ Restart=always
#~ RestartSec=3s
#~ TimeoutStopSec=7s
#~ User=${USERNAMEVAR}

#~ [Install]
#~ WantedBy=graphical.target
#~ EOL
#~ systemctl daemon-reload
#~ systemctl enable "$SDSERVICE"

