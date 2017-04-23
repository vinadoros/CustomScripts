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
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
fi
export USERGROUP=$(id $USERNAMEVAR -gn)
export USERHOME=/home/$USERNAMEVAR

if [ -z $DEBRELEASE ]; then
	DEBRELEASE=$(lsb_release -sc)
fi

# Set default user environment if none exist.
if [ -z $SETDE ]; then
	SETDE=0
fi

[ -z "$MACHINEARCH" ] && MACHINEARCH="$(uname -m)"

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install software

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

add-apt-repository -y "$PPA"
apt-get update
keymissing
EOL

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
ppa ppa:fish-shell/release-2
apt-get install -y fish
FISHPATH=$(which fish)
if ! grep -iq "$FISHPATH" /etc/shells; then
	echo "$FISHPATH" | tee -a /etc/shells
fi

# For general desktop
apt-get install -y synaptic gdebi gparted xdg-utils leafpad nano
apt-get install -y gnome-disk-utility btrfs-tools f2fs-tools dmraid mdadm
DEBIAN_FRONTEND=noninteractive apt-get install -y nbd-client

# Timezone stuff
dpkg-reconfigure -f noninteractive tzdata

# CLI and system utilities
apt-get install -y curl rsync less iotop
# Needed for systemd user sessions.
apt-get install -y dbus-user-session

# Samba
apt-get install -y samba

# NTP
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Avahi
apt-get install -y avahi-daemon avahi-discover libnss-mdns

# Cups-pdf
apt-get install -y printer-driver-cups-pdf

# Audio
apt-get install -y alsa-utils pavucontrol paprefs pulseaudio-module-zeroconf pulseaudio-module-bluetooth

# Media Playback
apt-get install -y vlc audacious ffmpeg

# Fonts
apt-get install -y fonts-powerline fonts-noto fonts-roboto

# Browsers
apt-get install -y chromium-browser firefox flashplugin-installer

# Terminals
# apt-get install -y terminator
ppa ppa:webupd8team/terminix
apt-get install -y tilix

# Cron
apt-get install -y cron anacron
systemctl disable cron
systemctl disable anacron

# Network manager
apt-get install -y network-manager network-manager-ssh
sed -i 's/managed=.*/managed=true/g' /etc/NetworkManager/NetworkManager.conf
# https://askubuntu.com/questions/882806/ethernet-device-not-managed
if [ -f /etc/NetworkManager/conf.d/10-globally-managed-devices.conf ]; then
	rm /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
fi
touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf


###############################################################################
######################        Desktop Environments      #######################
###############################################################################
# Case for SETDE variable.
case $SETDE in
[1]* )
		# GNOME
		echo "GNOME stuff."
		apt-get install -y ubuntu-gnome-desktop
		apt-get install -y gnome-shell-extension-dashtodock gnome-shell-extension-mediaplayer gnome-shell-extension-top-icons-plus gnome-shell-extension-gpaste
		$SCRIPTDIR/DExtGnome.sh -v
    ;;
[2]* )
		# KDE
		echo "KDE stuff."
	;;
[3]* )
    # MATE
    echo "MATE stuff."
		apt-get install -y ubuntu-mate-core ubuntu-mate-default-settings ubuntu-mate-desktop
		apt-get install -y ubuntu-mate-lightdm-theme
		apt-get install -y dconf-cli
		;;
* ) echo "Not changing desktop environment."
    ;;
esac


# Numix
ppa ppa:numix/ppa
apt-get install -y numix-icon-theme-circle

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
	apt-get install -y --no-install-recommends tlp smartmontools ethtool

fi
