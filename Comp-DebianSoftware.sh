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

	dist_install equivs
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
	dist_install apt-config-auto-update

	# Set up GPG.
	# Make sure .gnupg folder exists for root
	if [ ! -d /root/.gnupg ]; then
		echo "Creating /root/.gnupg folder."
		gpg --list-keys
		# Have gnupg autoretrieve keys.
		if [ -f /root/.gnupg/gpg.conf ]; then
			sed -i 's/#keyserver-options auto-key-retrieve/keyserver-options auto-key-retrieve/g' ~/.gnupg/gpg.conf
		fi
	else
		echo "Skipping /root/.gnupg creation, folder exists."
	fi

	# Set gnupg to auto-retrive keys. This is needed for some aur packages.
	su $USERNAMEVAR -s /bin/bash <<'EOL'
		# First create the gnupg database if it doesn't exist.
		if [ ! -d ~/.gnupg ]; then
			gpg --list-keys
		fi
		# Have gnupg autoretrieve keys.
		if [ -f ~/.gnupg/gpg.conf ]; then
			sed -i 's/#keyserver-options auto-key-retrieve/keyserver-options auto-key-retrieve/g' ~/.gnupg/gpg.conf
		fi
EOL

fi

# Set up import missing keys.
multilinereplace "/usr/bin/local/keymissing" <<"EOFXYZ"
#!/bin/bash
sudo apt-get update 2> /tmp/keymissing
if [ -f /tmp/keymissing ]
then
	for key in $(grep "NO_PUBKEY" /tmp/keymissing |sed "s/.*NO_PUBKEY //")
			do
			echo -e "\nProcessing key: $key"
			sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $key
			sudo apt-get update
	done
	rm /tmp/keymissing
fi
EOFXYZ

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
keymissing
EOL
chmod a+rwx "$PPASCRIPT"

# Make user part of sudo group
dist_install sudo
usermod -aG sudo $USERNAMEVAR
# Delete defaults in sudoers for Debian.
if grep -iq $'^Defaults\tenv_reset' /etc/sudoers; then
	sed -i $'/^Defaults\tenv_reset/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tmail_badpass/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tsecure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c

# Install openssh
dist_install ssh tmux

# Install fish
dist_install fish
FISHPATH=$(which fish)
if ! grep -iq "$FISHPATH" /etc/shells; then
	echo "$FISHPATH" | tee -a /etc/shells
fi

# For general desktop
dist_install synaptic gdebi gparted xdg-utils leafpad
dist_install gnome-disk-utility btrfs-tools f2fs-tools
DEBIAN_FRONTEND=noninteractive apt-get install -y nbd-client

# Timezone stuff
dpkg-reconfigure -f noninteractive tzdata

# CLI utilities
dist_install curl rsync less

# Samba
dist_install samba winbind

# NTP
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Avahi
dist_install avahi-daemon avahi-discover libnss-mdns

# Cups-pdf
dist_install cups-pdf

# Audio
dist_install alsa-utils pavucontrol paprefs pulseaudio-module-zeroconf pulseaudio-module-bluetooth

# Media Playback
dist_install vlc audacious ffmpeg

# Browsers
[ "$OS" = "Debian" ] && dist_install chromium
[ "$OS" = "Ubuntu" ] && dist_install chromium-browser

# Utils
dist_install iotop

# Cron
dist_install cron anacron
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
	elif [ "$OS" = "Debian" ]; then
		debequivs "iceweasel"
		debequivs "gnome-user-share"

		# Locale fix for gnome-terminal.
		localectl set-locale LANG="en_US.UTF-8"

		dist_install gnome-core alacarte desktop-base file-roller gedit gedit-plugins gnome-clocks gnome-color-manager gnome-logs gnome-nettool gnome-tweak-tool seahorse gnome-shell-extensions-gpaste
		dist_install gdm3
		dist_install gnome-packagekit network-manager-gnome
	fi

    break;;

[3]* )
    # MATE
    echo "MATE stuff."

	if [ "$OS" = "Ubuntu" ]; then
		dist_install ubuntu-mate-core ubuntu-mate-default-settings ubuntu-mate-desktop
		dist_install ubuntu-mate-lightdm-theme
	elif [ "$OS" = "Debian" ]; then
		dist_install mate-desktop-environment caja-open-terminal caja-gksu caja-share dconf-editor gnome-keyring mate-sensors-applet mozo
		dist_install lightdm accountsservice
		dist_install gnome-packagekit pk-update-icon network-manager-gnome
	fi

	dist_install dconf-cli

    break;;

* ) echo "Not changing desktop environment."
    break;;
esac



# PPA software
ppa ppa:numix/ppa
dist_install numix-icon-theme-circle


if [ "${MACHINEARCH}" != "armv7l" ]; then
	echo "Install x86 specific software."

	# TLP
	dist_install tlp smartmontools ethtool

	# Liquorix repo
	if ! grep -iq "liquorix.net" /etc/apt/sources.list; then
		echo "Installing liquorix kernel."
		add-apt-repository "deb http://liquorix.net/debian sid main past"
		apt-get update
		apt-get install -y --force-yes liquorix-keyring
		apt-get update
		# Install kernels.
		[ "${MACHINEARCH}" = "x86_64" ] && dist_install linux-image-liquorix-amd64 linux-headers-liquorix-amd64
		[ "${MACHINEARCH}" = "i686" ] && dist_install linux-image-liquorix-686-pae linux-headers-liquorix-686-pae
		# Remove stock kernels if installed.
		dpkg-query -l | grep -iq "linux-image-amd64" && apt-get --purge remove -y linux-image-amd64
		dpkg-query -l | grep -iq "linux-image-686-pae" && apt-get --purge remove -y linux-image-686-pae
		dpkg-query -l | grep -iq "linux-headers-generic" && apt-get --purge remove -y linux-headers-generic
	fi

elif [ "${MACHINEARCH}" = "armv7l" ]; then
	echo "Install arm specific software."

	# Install omxplayer
	if ! dpkg-query -l | grep -iq "omxplayer"; then
		dist_install xclip youtube-dl
		wget -P ~/ "${OMXURL}"
		gdebi -n ~/omxplayer*.deb
		rm ~/omxplayer*.deb
	fi


	if [ "$OS" = "Ubuntu" ]; then

		# Linux firmware
		dist_install linux-firmware

		# NTP Fix
		if type -P ntpd &> /dev/null; then
			dist_install ntpdate
		fi

	elif [ "$OS" = "Debian" ]; then

		# Linux Firmware
		dist_install firmware-linux

		# Iceweasel
		dist_install iceweasel

		# Midori
		dist_install midori

	fi

	# Rpi watchdog
	dist_install watchdog
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
