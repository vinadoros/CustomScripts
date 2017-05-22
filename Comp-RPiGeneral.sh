#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

# Set user folders.
if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
	export USERNAMEVAR=$SUDO_USER
elif [ "$USER" != "root" ]; then
	export USERNAMEVAR=$USER
else
	export USERNAMEVAR=$(id 1000 -un)
fi
export USERGROUP=$(id $USERNAMEVAR -gn)
export USERHOME=/home/$USERNAMEVAR

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install rpi-update script
if ! type rpi-update; then
	wget -O /usr/local/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update
	chmod +x /usr/local/bin/rpi-update
fi

# Install rpi-update wrapper
RPIWRAPPER="/usr/local/bin/piup"
echo "Creating ${RPIWRAPPER}."
bash -c "cat >${RPIWRAPPER}" <<EOLXYZ
#!/bin/bash
SKIP_KERNEL=1 SKIP_BACKUP=1 rpi-update
EOLXYZ
chmod a+rwx "${RPIWRAPPER}"

# Create script for setting audio output using alsa
ALSASCRIPT="/usr/local/bin/aa"
echo "Creating ${ALSASCRIPT}."
bash -c "cat >${ALSASCRIPT}" <<'EOLXYZ'
#!/bin/bash
echo "Setting alsa output for RaspberryPi."
ALSASETTING="$1"
case "$ALSASETTING" in
[0-2])
	if [ $ALSASETTING = 0 ]; then echo "Setting output to auto (0)."; fi
	if [ $ALSASETTING = 1 ]; then echo "Setting output to headphones (1)."; fi
	if [ $ALSASETTING = 2 ]; then echo "Setting output to hdmi (2)."; fi
	sudo amixer -c 0 cset numid=3 $ALSASETTING > /dev/null
	;;
*)
	echo "No valid input. Defaulting to auto."
	echo "Setting output to auto (0)."
	sudo amixer -c 0 cset numid=3 0 > /dev/null
	;;
esac

EOLXYZ
chmod a+rwx "${ALSASCRIPT}"

# Disable pulseaudio suspend-on-idle
if [ -f /etc/pulse/system.pa ]; then
	sed -i '/load-module module-suspend-on-idle/ s/^#*/#/' /etc/pulse/system.pa
fi

# OMXPlayer + YouTube script
YTSCRIPT=/usr/local/bin/yt
echo "Creating ${YTSCRIPT}."
bash -c "cat >${YTSCRIPT}" <<'EOLXYZ'
#!/bin/bash
set -e
if [ -z "$1" ]; then
	echo "No url. Exiting."
	exit 0;
else
	YT_URL="$1"
fi
if [ ! -z "$2" ]; then
	OMXOPTS="-l $2"
else
	OMXOPTS=""
fi
echo "Getting URL for $YT_URL"
OMXURL="$(youtube-dl -g -f best $YT_URL)"
echo "Playing $OMXURL"
omxplayer -o both "$OMXURL" "$OMXOPTS"
EOLXYZ
chmod a+rwx "${YTSCRIPT}"

# OMXPlayer + YouTube clipboard script
YTCLIPSCRIPT=/usr/local/bin/ytclip
echo "Creating ${YTCLIPSCRIPT}."
bash -c "cat >${YTCLIPSCRIPT}" <<"EOLXYZ"
#!/bin/bash
set -x
YTURL="$(xclip -selection clipboard -o)"
if ! echo "$YTURL" | grep -iq youtube; then
	echo "Error. Clipboard contains $YTURL"
else
	echo "Playing $YTURL"
	yt "$YTURL"
fi
sleep 1
EOLXYZ
chmod a+rwx "${YTCLIPSCRIPT}"

if [ -d $USERHOME/Desktop ]; then
	# OMXPlayer + YouTube clipboard desktop file
	YTCLIPDESKTOP=$USERHOME/Desktop/ytclip.desktop
	echo "Creating ${YTCLIPDESKTOP}."
	bash -c "cat >${YTCLIPDESKTOP}" <<"EOLXYZ"
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Terminal=true
Exec=/usr/local/bin/ytclip
Name=YoutubeOMX
Comment=Youtube + OMXPlayer clipboard script
EOLXYZ
	chmod a+rwx "${YTCLIPDESKTOP}"

	# OMXPlayer desktop file
	OMXDESKTOP=$USERHOME/Desktop/omxplayer.desktop
	echo "Creating ${OMXDESKTOP}."
	bash -c "cat >${OMXDESKTOP}" <<"EOLXYZ"
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Terminal=true
Exec=omxplayer %f
Name=OMXplayer
Comment=OMXplayer
EOLXYZ
	chmod a+rwx "${OMXDESKTOP}"
fi
