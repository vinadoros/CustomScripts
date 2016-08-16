#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

set +eu

# URL for omxplayer deb file.
# http://omxplayer.sconde.net/
OMXURL="http://omxplayer.sconde.net/builds/omxplayer_0.3.6~git20150627~843744e_armhf.deb"

# Add general functions if they don't exist.
type -t grepadd >> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

# Set user folders if they don't exist.
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

if [ -z $DEBRELEASE ]; then
	DEBRELEASE=$(lsb_release -sc)
fi

# Set default user environment if none exist.
if [ -z $SETDE ]; then
	SETDE=0
fi

if [ -z $OS ]; then
	OS=$(lsb_release -si)
fi

[ -z "$MACHINEARCH" ] && MACHINEARCH="$(uname -m)"

# Enable error halting.
set -eu

function debequivs () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		EQUIVPACKAGE="$1"
	fi

	apt-get install -y equivs
	if ! dpkg -l | grep -i "$EQUIVPACKAGE"; then
		echo "Creating and installing dummy package $EQUIVPACKAGE."
		bash -c "cat >/var/tmp/$EQUIVPACKAGE" <<EOL
Package: $EQUIVPACKAGE
Version: 999.0
Priority: optional
EOL
		cd /var/tmp
		equivs-build "$EQUIVPACKAGE"
		dpkg -i ./"$EQUIVPACKAGE"*.deb
		rm ./"$EQUIVPACKAGE"*
	fi
}

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install software

# Ubuntu specific and debian specific global here.
if [ "$OS" = "Ubuntu" ]; then
	echo "Installing Ubuntu specific software."

elif [ "$OS" = "Debian" ]; then
	echo "Installing Debian specific software."

	# Apt updating sources
	apt-get install -y apt-config-auto-update

fi

# PPASCRIPT, common to Debian and Ubuntu for now.
PPASCRIPT="/usr/local/bin/ppa"
echo "Creating $PPASCRIPT"
bash -c "cat >$PPASCRIPT" <<'EOL'
#!/bin/bash

if [ -z $1 ]; then
	echo "No PPA specified. Exiting."
	exit 1;
fi

#Error handling.
set -eu

#Variables
PPA="$1"

add-apt-repository -y "$PPA"
apt-get update
EOL
chmod a+rwx "$PPASCRIPT"

# Make user part of sudo group
apt-get install -y sudo
usermod -aG sudo $USERNAMEVAR
# Delete defaults in sudoers for Debian.
if grep -iq $'^Defaults\tenv_reset' /etc/sudoers; then
	sed -i $'/^Defaults\tenv_reset/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tmail_badpass/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tsecure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c

# Install openssh
apt-get install -y ssh tmux

# Install fish
apt-get install -y fish
FISHPATH=$(which fish)
if ! grep -iq "$FISHPATH" /etc/shells; then
	echo "$FISHPATH" | tee -a /etc/shells
fi

# For general desktop
apt-get install -y synaptic gdebi gparted xdg-utils leafpad
apt-get install -y gnome-disk-utility btrfs-tools f2fs-tools
DEBIAN_FRONTEND=noninteractive apt-get install -y nbd-client

# Timezone stuff
dpkg-reconfigure -f noninteractive tzdata

# CLI utilities
apt-get install -y curl rsync less

# Samba
apt-get install -y samba winbind

# NTP
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Avahi
apt-get install -y avahi-daemon avahi-discover libnss-mdns

# Cups-pdf
apt-get install -y cups-pdf

# Audio
apt-get install -y alsa-utils pavucontrol paprefs pulseaudio-module-zeroconf pulseaudio-module-bluetooth

# Media Playback
apt-get install -y vlc audacious ffmpeg

# Browsers
[ "$OS" = "Debian" ] && apt-get install chromium
[ "$OS" = "Ubuntu" ] && apt-get install chromium-browser

# Utils
apt-get install -y iotop

# Cron
apt-get install -y cron anacron
systemctl disable cron
systemctl disable anacron

# Apt updating sources
APTUPDTSCR="/etc/apt/apt.conf.d/99custom"
echo "Creating $APTUPDTSCR"
bash -c "cat >$APTUPDTSCR" <<'EOL'
APT::Periodic::Enable "1";
APT::Periodic::AutocleanInterval "1";
APT::Periodic::Unattended-Upgrade "1";
EOL


###############################################################################
######################        Desktop Environments      #######################
###############################################################################
# Case for SETDE variable. 0=do nothing, 1=KDE, 2=cinnamon
case $SETDE in
[1]* )
    # KDE
    echo "KDE stuff."

    break;;

[2]* )
    # GNOME
    echo "GNOME stuff."

	if [ "$OS" = "Ubuntu" ]; then
		echo ""
		#apt-get install -y mate-terminal
	elif [ "$OS" = "Debian" ]; then
		debequivs "iceweasel"
		debequivs "gnome-user-share"

		# Locale fix for gnome-terminal.
		localectl set-locale LANG="en_US.UTF-8"

		apt-get install -y gnome-core alacarte desktop-base file-roller gedit gedit-plugins gnome-clocks gnome-color-manager gnome-logs gnome-nettool gnome-tweak-tool seahorse gnome-shell-extensions-gpaste
		apt-get install -y gdm3
		apt-get install -y gnome-packagekit network-manager-gnome
	fi

    break;;

[3]* )
    # MATE
    echo "MATE stuff."

	if [ "$OS" = "Ubuntu" ]; then
		apt-get install -y ubuntu-mate-core ubuntu-mate-default-settings ubuntu-mate-desktop
		apt-get install -y ubuntu-mate-lightdm-theme
	elif [ "$OS" = "Debian" ]; then
		apt-get install -y mate-desktop-environment caja-open-terminal caja-gksu caja-share dconf-editor gnome-keyring mate-gnome-main-menu-applet mate-netspeed mate-sensors-applet mozo
		apt-get install -y lightdm accountsservice
		apt-get install -y gnome-packagekit pk-update-icon network-manager-gnome
	fi

	apt-get install -y dconf-cli

    break;;

* ) echo "Not changing desktop environment."
    break;;
esac



# PPA software
ppa ppa:numix/ppa
apt-get install -y numix-icon-theme-circle


if [ "${MACHINEARCH}" != "armv7l" ]; then
	echo "Install x86 specific software."

	# TLP
	apt-get install -y tlp smartmontools ethtool

	# Liquorix repo
	if ! grep -iq "liquorix.net" /etc/apt/sources.list; then
		echo "Installing liquorix kernel."
		add-apt-repository "deb http://liquorix.net/debian sid main past"
		apt-get update
		apt-get install -y --force-yes liquorix-keyring
		apt-get update
		# Install kernels.
		[ "${MACHINEARCH}" = "x86_64" ] && apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64
		[ "${MACHINEARCH}" = "i686" ] && apt-get install -y linux-image-liquorix-686-pae linux-headers-liquorix-686-pae
		# Remove stock kernels if installed.
		dpkg-query -l | grep -iq "linux-image-amd64" && apt-get --purge remove -y linux-image-amd64
		dpkg-query -l | grep -iq "linux-image-686-pae" && apt-get --purge remove -y linux-image-686-pae
		dpkg-query -l | grep -iq "linux-headers-generic" && apt-get --purge remove -y linux-headers-generic
	fi

elif [ "${MACHINEARCH}" = "armv7l" ]; then
	echo "Install arm specific software."

	# Install omxplayer
	if ! dpkg-query -l | grep -iq "omxplayer"; then
		apt-get install -y xclip youtube-dl
		wget -P ~/ "${OMXURL}"
		gdebi -n ~/omxplayer*.deb
		rm ~/omxplayer*.deb
	fi


	if [ "$OS" = "Ubuntu" ]; then

		# Linux firmware
		apt-get install -y linux-firmware

		# NTP Fix
		if type -P ntpd &> /dev/null; then
			apt-get install -y ntpdate
		fi

	elif [ "$OS" = "Debian" ]; then

		# Linux Firmware
		apt-get install -y firmware-linux

		# Iceweasel
		apt-get install -y iceweasel

		# Midori
		apt-get install -y midori

	fi

	# Rpi watchdog
	apt-get install -y watchdog
	#~ sed -i 's/watchdog_module=.*$/watchdog_module="bcm2708_wdog"/g' /etc/default/watchdog
	bash -c "cat >/lib/systemd/system/wdt_bcm.service" <<'EOL'
[Unit]
Description=Watchdog Daemon

[Service]
Type=forking
PIDFile=/run/watchdog.pid
ExecStart=/usr/sbin/watchdog
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
	systemctl enable wdt_bcm.service
	echo "bcm2708_wdog" > /etc/modules-load.d/bcm2708_wdog.conf

fi
