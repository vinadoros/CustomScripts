#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

set +eu

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
if [ "$DEBRELEASE" != "jessie" ]; then
	set -eu
fi

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
KEYMISSSCRIPT="/usr/local/bin/keymissing"
multilinereplace "$KEYMISSSCRIPT" <<'EOL'
#!/bin/bash
APTLOG=/tmp/aptlog
sudo apt-get update 2> $APTLOG
if [ -f $APTLOG ]
then
	for key in $(grep "NO_PUBKEY" $APTLOG |sed "s/.*NO_PUBKEY //"); do
			echo -e "\nProcessing key: $key"
			sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $key
			sudo apt-get update
	done
	rm $APTLOG
fi
EOL
chmod a+rwx "$KEYMISSSCRIPT"

# PPASCRIPT, common to Debian and Ubuntu for now.
PPASCRIPT="/usr/local/bin/ppa"
multilinereplace "$PPASCRIPT" <<'EOL'
#!/bin/bash

if [ -z $1 ]; then
	echo "No PPA specified. Exiting."
	exit 1;
fi

#Variables
PPA="$1"
OS="$(lsb_release -si)"

if [ $OS = "Ubuntu" ]; then
	add-apt-repository -y "$PPA"
else
	ppa_name=$(echo "$PPA" | cut -d":" -f2 -s)
	add-apt-repository -y "deb http://ppa.launchpad.net/$ppa_name/ubuntu yakkety main"
fi
apt-get update
keymissing
EOL

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
if [ "$OS" = "Ubuntu" ]; then
	ppa ppa:fish-shell/release-2
fi
dist_install fish
FISHPATH=$(which fish)
if ! grep -iq "$FISHPATH" /etc/shells; then
	echo "$FISHPATH" | tee -a /etc/shells
fi

# For general desktop
dist_install synaptic gdebi gparted xdg-utils leafpad nano
dist_install gnome-disk-utility btrfs-tools f2fs-tools dmraid mdadm
DEBIAN_FRONTEND=noninteractive apt-get install -y nbd-client

# Timezone stuff
dpkg-reconfigure -f noninteractive tzdata

# CLI and system utilities
dist_install curl rsync less
# Needed for systemd user sessions.
if [ "$DEBRELEASE" != "jessie" ]; then
	dist_install dbus-user-session
fi

# Samba
dist_install samba winbind

# NTP
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Avahi
dist_install avahi-daemon avahi-discover libnss-mdns

# Cups-pdf
dist_install printer-driver-cups-pdf

# Audio
dist_install alsa-utils pavucontrol paprefs pulseaudio-module-zeroconf pulseaudio-module-bluetooth

# Media Playback
dist_install vlc audacious ffmpeg

# Fonts
dist_install fonts-powerline fonts-noto

# Browsers
[ "$OS" = "Debian" ] && dist_install chromium
[ "$OS" = "Ubuntu" ] && dist_install chromium-browser
dist_install firefox

# Utils
dist_install iotop

# Terminals
# dist_install terminator
# dist_install terminix

# Cron
dist_install cron anacron
systemctl disable cron
systemctl disable anacron

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
		# Locale fix for gnome-terminal.
		localectl set-locale LANG="en_US.UTF-8"

		dist_install gnome-core alacarte desktop-base file-roller gedit gnome-clocks gnome-color-manager gnome-logs gnome-nettool gnome-tweak-tool seahorse
		# Shell extensions
		dist_install gnome-shell-extensions-gpaste gnome-shell-extension-top-icons-plus gnome-shell-extension-mediaplayer
		dist_install gdm3
		dist_install gnome-packagekit network-manager-gnome
		$SCRIPTDIR/DExtGnome.sh -d -v
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
if [ "$DEBRELEASE" != "jessie" ]; then
	ppa ppa:numix/ppa
	dist_install numix-icon-theme-circle
fi

###############################################################################
##########################        Guest Section      ##########################
###############################################################################
# Install virtualbox guest utils
if [ $VBOXGUEST = 1 ]; then
	apt-get install -y virtualbox-guest-utils virtualbox-guest-dkms dkms

	# Add the user to the vboxsf group, so that the shared folders can be accessed.
	gpasswd -a $USERNAMEVAR vboxsf

fi
# Install qemu/kvm guest utils.
if [ $QEMUGUEST = 1 ]; then
	apt-get install -y spice-vdagent qemu-guest-agent

fi
# Install VMWare guest utils
if [ $VMWGUEST = 1 ]; then
	apt-get install -y open-vm-tools open-vm-tools-dkms open-vm-tools-desktop
fi

###############################################################################
##################        Architecture Specific Section     ###################
###############################################################################
if [ "${MACHINEARCH}" != "armv7l" ]; then
	echo "Install x86 specific software."

	# TLP
	dist_install tlp smartmontools ethtool

fi
