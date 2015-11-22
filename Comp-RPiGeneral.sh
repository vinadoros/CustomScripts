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

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Add startup modules.
if ! grep -iq "snd-bcm2835" /etc/modules-load.d/modules.conf; then
	echo "snd-bcm2835" | tee -a /etc/modules-load.d/modules.conf
	echo "configs" | tee -a /etc/modules-load.d/modules.conf
fi

# Add fstab line for boot and 2nd flash partition
if ! grep -iq "mmcblk0p1" /etc/fstab; then
	blank=$(tail -1 /etc/fstab)
	if [ "$blank" != '' ]; then
		echo "" | sudo tee -a /etc/fstab
	fi
	echo -e "/dev/mmcblk0p1\t/boot\tvfat\tdefaults,umask=0,noauto\t0\t0" | tee -a /etc/fstab
fi
if ! grep -iq "mmcblk0p2" /etc/fstab; then
	blank=$(tail -1 /etc/fstab)
	if [ "$blank" != '' ]; then
		echo "" | sudo tee -a /etc/fstab
	fi
	echo -e "#/dev/mmcblk0p2\t/\tauto\trw,defaults\t0\t0" | tee -a /etc/fstab
fi

# Install rpi-update script
if [[ ! $(type -P rpi-update) ]]; then
	wget -O /usr/local/bin/rpi-update https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update
	chmod +x /usr/local/bin/rpi-update
fi

# Install rpi-update wrapper
RPIWRAPPER="/usr/local/bin/piup"
echo "Creating ${RPIWRAPPER}."
bash -c "cat >${RPIWRAPPER}" <<EOLXYZ
#!/bin/bash
if ! mount | grep -q "/boot type vfat"; then
	echo "Boot not mounted. Exiting"
	exit 1;
fi
sudo SKIP_KERNEL=1 SKIP_BACKUP=1 rpi-update
EOLXYZ
chmod a+rwx "${RPIWRAPPER}"

# Perform update if no VideoCore libraries
if [ ! -d /opt/vc ]; then
	if mount | grep -q "/boot type vfat"; then
		echo "Boot mounted."
	else
		echo "Mounting boot."
		mount /boot
	fi
	if [ -f "/boot/.firmware_revision" ]; then
		echo "Removing /boot/.firmware_revision"
		rm -f "/boot/.firmware_revision"
	fi
	echo "Running ${RPIWRAPPER}."
	"${RPIWRAPPER}"
fi

# Enable lightdm autologin.
if [ -f /etc/lightdm/lightdm.conf ]; then
	sed -i 's/#autologin-user=/autologin-user='$USERNAMEVAR'/g' /etc/lightdm/lightdm.conf
fi

if [ -f /etc/systemd/system/display-manager.service ] && ls -la /etc/systemd/system/display-manager.service | grep -iq "lightdm"; then
	if [[ ! -f /etc/lightdm/lightdm.conf && ! -f /etc/lightdm/lightdm.conf.d/50-autologin.conf ]]; then
		if [ ! -d /etc/lightdm/lightdm.conf.d/ ]; then
			echo "Creating /etc/lightdm/lightdm.conf.d/"
			mkdir -p /etc/lightdm/lightdm.conf.d/
			chmod a+rwx -R /etc/lightdm/lightdm.conf.d/
		fi
		echo "Creating /etc/lightdm/lightdm.conf.d/50-autologin.conf"
		bash -c "cat >>/etc/lightdm/lightdm.conf.d/50-autologin.conf" <<EOLXYZ
[SeatDefaults]
autologin-user=$USERNAMEVAR
autologin-user-timeout=0 
EOLXYZ
		chmod a+rwx /etc/lightdm/lightdm.conf.d/50-autologin.conf
	fi
fi

# Add udev rule for /dev/vchiq for omxplayer.
# http://elinux.org/Omxplayer
if [ ! -f /etc/udev/rules.d/10-vchiq-permissions.rules ]; then
	echo 'SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"' | tee -a /etc/udev/rules.d/10-vchiq-permissions.rules
fi

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
set -eu
YT_URL="$1"
omxplayer -o both "$(youtube-dl -g -f best $YT_URL)"
EOLXYZ
chmod a+rwx "${YTSCRIPT}"

# OMXPlayer + YouTube clipboard script
YTCLIPSCRIPT=/usr/local/bin/ytclip
echo "Creating ${YTCLIPSCRIPT}."
bash -c "cat >${YTCLIPSCRIPT}" <<"EOLXYZ"
#!/bin/bash
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

# Vlc + YouTube audio clipboard script
YTAUDIOSCRIPT=/usr/local/bin/ytaudio
echo "Creating ${YTAUDIOSCRIPT}."
bash -c "cat >${YTAUDIOSCRIPT}" <<"EOLXYZ"
#!/bin/bash
YTURL="$(xclip -selection clipboard -o)"
if ! echo "$YTURL" | grep -iq youtube; then
	echo "Error. Clipboard contains $YTURL"
else
	echo "Playing $YTURL"
	vlc "$(youtube-dl -gx -f bestaudio $YTURL)"
fi
sleep 1
EOLXYZ
chmod a+rwx "${YTAUDIOSCRIPT}"

# OMXPlayer desktop file
YTAUDIODESKTOP=$USERHOME/Desktop/ytaudio.desktop
echo "Creating ${YTAUDIODESKTOP}."
bash -c "cat >${YTAUDIODESKTOP}" <<"EOLXYZ"
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Terminal=true
Exec=ytaudio
Name=Youtube Audio
Comment=Youtube Audio Player
EOLXYZ
chmod a+rwx "${YTAUDIODESKTOP}"

# Watchdog scripts
if [ -f /etc/watchdog.conf ] && ! grep -iq "^watchdog-device" /etc/watchdog.conf; then
	echo "Appending /etc/watchdog.conf."
	bash -c "cat >>/etc/watchdog.conf" <<'EOL'
watchdog-device = /dev/watchdog
watchdog-timeout = 14
realtime = yes
priority = 1
interval = 4
pidfile = /run/watchdog.pid
ping = 127.0.0.1
EOL
fi
echo "Creating /usr/local/bin/wdt."
bash -c "cat >/usr/local/bin/wdt" <<'EOL'
#!/bin/bash

if [ -f /lib/systemd/system/wdt_bcm.service ]; then
	WDTSVC="wdt_bcm.service"
else
	WDTSVC="watchdog.service"
fi

case "$1" in
  "start")
    echo "Starting watchdog service."
    sudo modprobe bcm2708_wdog
    sudo systemctl restart "$WDTSVC"
    sudo systemctl status "$WDTSVC"
    ;;
  "stop")
    echo "Stopping watchdog service."
    sudo systemctl stop "$WDTSVC"
    sleep 0.5
	sudo modprobe -r bcm2708_wdog
    sudo systemctl status "$WDTSVC"
    ;;
  *)
    echo "Usage: `basename $0` (start | stop)"
    exit 1
    ;;
esac
EOL
chmod a+rwx /usr/local/bin/wdt
