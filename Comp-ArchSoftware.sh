#!/bin/bash

# Disable error handling
set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

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

# Set default user environment if none exist.
[ -z $SETDE ] && SETDE=0
[ -z $SETDM ] && SETDM=0

# Set default VM guest variables
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0

# Set machine architecture
[ -z "$MACHINEARCH" ] && MACHINEARCH=$(uname -m)

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install software

# Install randomness generator
dist_install haveged
systemctl enable haveged

# Update system
pacman -Syu --needed --noconfirm

# Add groups to current user
GROUPSTOADD=(lp network video audio storage scanner power disk sys games optical avahi uucp systemd-journal)
addgrouptouser GROUPSTOADD[@] $USERNAMEVAR

# Remove xnoise, if it exists
if (pacman -Q xnoise &>/dev/null); then
	pacman -Rs --noconfirm xnoise
fi

# Setup devel stuff
dist_install rsync base-devel

# Xorg stuff
dist_install xdg-utils xdg-user-dirs perl-file-mimeinfo


###############################################################################
########################        Display Managers      #########################
###############################################################################


# Case for SETDM variable.
case $SETDM in
[1]* )
	echo "Setting up SDDM."
	dist_install sddm
	systemctl enable -f sddm
	;;

[2]* )
	echo "Setting up lightdm with GTK greeter."
	dist_install lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
	systemctl enable -f lightdm
	sed -i 's/greeter-session=.*$/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
	;;

[3]* )
	echo "Setting up GDM."
	dist_install gdm
	systemctl enable -f gdm
	;;

[4]* )
	echo "Setting up lightdm with KDE greeter."
	dist_install lightdm lightdm-kde-greeter
	systemctl enable -f lightdm
	sed -i 's/greeter-session=.*$/greeter-session=lightdm-kde-greeter/g' /etc/lightdm/lightdm.conf
	;;

* ) echo "Not changing display manager settings."
	;;
esac


###############################################################################
######################        Desktop Environments      #######################
###############################################################################

# Case for SETDE variable.
case $SETDE in
[1]* )
	# Install KDE
	echo "Installing KDE."
	dist_install plasma-meta
	# KDE Software
	dist_install kate dolphin konsole
	dist_install kwrite okular ebook-tools ark unzip zip p7zip unrar
	;;

[2]* )
	# Install cinnamon
	echo "Installing Cinnamon."
	dist_install cinnamon nemo-fileroller nemo-preview nemo-share evince eog baobab gnome-calculator gnome-font-viewer gnome-disk-utility gnome-icon-theme gnome-system-log gnome-system-monitor gnome-terminal totem vino file-roller cdrkit lrzip unace unrar gnome-color-manager gedit gnome-clocks seahorse gufw gnome-logs
	;;

[3]* )
	# Install GNOME
	echo "Installing GNOME."
	dist_install gnome file-roller cdrkit lrzip unace unrar gedit gnome-clocks seahorse gufw gnome-tweak-tool gnome-logs dconf-editor gpaste
	# Install gnome shell extensions and misc apps
	dist_install gnome-shell-extension-dash-to-dock-git
	dist_install gnome-shell-extension-mediaplayer-git
	dist_install gnome-shell-extension-volume-mixer-git gnome-shell-extension-topicons-plus-git

	# XScreensaver
	dist_install xscreensaver
	;;

[4]* )
	# Install XFCE
	echo "Installing XFCE."
	dist_install xfce4 xfce4-goodies
	# Install xfce notification for volume and whisker menu
	dist_install xfce4-whiskermenu-plugin xfce4-volumed
	;;

[5]* )
	# Install MATE
	echo "Installing MATE."
	dist_install mate-gtk3 xdg-user-dirs-gtk gnome-themes-standard gnome-keyring seahorse dconf-editor
	# MATE Extras
	dist_install mate-menu mate-tweak atril-gtk3 caja-gksu-gtk3 caja-open-terminal-gtk3 caja-share-gtk3 engrampa eom-gtk3 gnome-calculator mate-applets-gtk3 mate-media-gtk3 mate-power-manager-gtk3 mate-sensors-applet-gtk3 mate-system-monitor mate-terminal mate-utils-gtk3 mozo pluma-gtk3 unrar mate-screensaver-gtk3 mate-icon-theme-faenza
	# Clipboard monitor
	dist_install clipit
	# cp /usr/share/applications/clipit.desktop $USERHOME/.config/autostart/
	multilinereplace "$USERHOME/.config/autostart/clipit.desktop" << EOFXYZ
[Desktop Entry]
Name=ClipIt
Comment=Clipboard Manager
Icon=clipit-trayicon
Exec=clipit
Terminal=false
Type=Application
Categories=GTK;GNOME;Application;Utility;
X-GNOME-Autostart-enabled=false
EOFXYZ
	chown $USERNAMEVAR:$USERGROUP "$USERHOME/.config/autostart/clipit.desktop"
	;;

[6]* )
		# Install lxqt
		echo "Installing lxqt."
		dist_install lxqt breeze-icons oxygen-icons xscreensaver libpulse libstatgrab libsysstat lm_sensors
		;;

* ) echo "Not changing desktop environment."
	;;
esac

# Misc software
if ! pacman -Q | grep -iq "numix-circle"; then
	# Remove numix-icon-theme, if it exists
	if (pacman -Q numix-icon-theme &>/dev/null); then
		pacman -Rsc --noconfirm numix-icon-theme
	fi
	dist_install numix-circle-icon-theme-git
fi

# AV Software
dist_install gst-libav gst-plugins-base gst-plugins-bad gst-plugins-good gst-plugins-ugly
# Pulseaudio
dist_install pavucontrol paprefs pulseaudio pulseaudio-alsa pulseaudio-gconf pulseaudio-zeroconf
# Bluetooth
dist_install bluez bluez-firmware bluez-hid2hci bluez-libs bluez-utils pulseaudio-bluetooth

dist_install leafpad gnome-disk-utility gparted p7zip unrar gvfs-smb gvfs-gphoto2 gvfs-goa gvfs-mtp gvfs-google gvfs-nfs libmtp systemd-ui meld
# System monitoring programs
dist_install iotop powertop jnettop nethogs
# Catfish search software
dist_install findutils mlocate

# Install avahi
dist_install avahi nss-mdns pygtk python2-dbus
systemctl enable avahi-daemon.service
usermod -aG avahi $USERNAMEVAR

# Install samba and winbind
dist_install samba
systemctl enable smbd
systemctl enable nmbd
systemctl enable winbindd

# Install fish shell
dist_install fish

# Setup ssh
dist_install openssh xorg-xauth tmux
systemctl enable sshd

# NTP configuration
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Install syncthing
dist_install syncthing syncthing-inotify syncthing-gtk
systemctl enable syncthing@$USERNAMEVAR

# Install pamac
dist_install pamac-aur

# Install utils for cron
dist_install run-parts

# Font packages
dist_install ttf-dejavu ttf-liberation ttf-ubuntu-font-family noto-fonts
bash <<EOF
cd /etc/fonts/conf.d
ln -s ../conf.avail/10-sub-pixel-rgb.conf
ln -s ../conf.avail/11-lcdfilter-default.conf
EOF

# For x86_64 only
if [ "${MACHINEARCH}" = "x86_64" ]; then
	echo "x86_64 Software for Arch."
fi

# For x86_64 and i686 only
if [ "${MACHINEARCH}" != "armv7l" ]; then
	echo "i686 and x86_64 Software for Arch."

	# Cups-pdf configuration
	dist_install cups-pdf
	systemctl enable org.cups.cupsd.service
	systemctl restart org.cups.cupsd.service
	if ! grep -iq "Desktop" /etc/cups/cups-pdf.conf; then
		echo "Out ${USERHOME}/Desktop" | tee -a /etc/cups/cups-pdf.conf
	fi
	# Set up a virtual printer named cups-pdf, set the resolution and page size.
	until lpadmin -p cups-pdf -v cups-pdf:/ -E -P /usr/share/cups/model/CUPS-PDF_opt.ppd
		do echo "Try again in 2 seconds."
		sleep 2
	done
	lpadmin -p cups-pdf -o Resolution=600dpi
	lpadmin -p cups-pdf -o PageSize=Letter
	# Cups PPD packages
	dist_install gutenprint foomatic-db foomatic-db-ppds foomatic-db-engine foomatic-db-gutenprint foomatic-db-gutenprint-ppds foomatic-db-nonfree foomatic-db-nonfree-ppds

	# Install laptop mode tools
	dist_install tlp smartmontools ethtool
	systemctl enable tlp
	systemctl enable tlp-sleep

	#Install atom editor.
	dist_install atom

	# Install reflector and sort mirrors for speed. Install service which loads on bootup.
	dist_install reflector
	reflector --verbose --country 'United States' -l 20 -f 20 -p http --sort rate --save /etc/pacman.d/mirrorlist
	cat >/etc/systemd/system/reflector.service <<'EOL'
[Unit]
Description=Pacman mirrorlist update
Requires=network-online.target
After=network.target nss-lookup.target network-online.target graphical.target

[Service]
Type=simple
ExecStart=/usr/bin/reflector --country 'United States' --protocol http -l 20 -f 20 --sort rate --save /etc/pacman.d/mirrorlist
Restart=on-failure
RestartSec=20s

[Install]
WantedBy=graphical.target
EOL
	systemctl enable reflector

	# Add multilib repo.
	if [ "${MACHINEARCH}" = "x86_64" ]; then
		if ! grep -Fxq "[multilib]" /etc/pacman.conf; then
			bash -c "cat >>/etc/pacman.conf" <<'EOL'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOL
		fi
	fi

	# Update system
	dist_update

	# Libreoffice
	dist_install libreoffice-fresh hunspell hunspell-en hyphen hyphen-en libmythes mythes-en

	# Email
	dist_install thunderbird thunderbird-i18n-en-us

	# Tilix
	dist_install tilix python2-nautilus

	###############################################################################
	######################       Live Computer Section      #######################
	###############################################################################
	# Install software for live computer.
	if [[ $VBOXGUEST = 0 && $QEMUGUEST = 0 && $VMWGUEST = 0 ]]; then
		# Media players
		dist_install vlc audacious smplayer youtube-dl
		# Clementine
		dist_install clementine
		# Wine
		dist_install wine alsa-lib alsa-plugins cups dosbox giflib lcms2 libcl libjpeg-turbo libldap libpng libpulse libxcomposite libxinerama libxml2 libxslt mpg123 ncurses openal samba v4l-utils wine_gecko wine-mono playonlinux
		if [ "${MACHINEARCH}" == "x86_64" ]; then
			dist_install lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-lcms2 lib32-libcl lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libpulse lib32-libxcomposite lib32-libxinerama lib32-libxml2 lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-v4l-utils lib32-sdl
		fi

		# For x86_64 only
		if [ "${MACHINEARCH}" = "x86_64" ]; then
			echo "x86_64 Software for Arch."

		fi

	fi

	# terminator
	dist_install terminator

	# Install browsers
	dist_install chromium
	dist_install firefox firefox-i18n-en-us
	dist_install pepper-flash freshplayerplugin

	###############################################################################
	#########################       Virtualbox Host      ##########################
	###############################################################################
	# Install virtualbox host
	if [[ $VBOXGUEST = 0 && $QEMUGUEST = 0 && $VMWGUEST = 0 ]]; then
		dist_install virtualbox-host-modules-arch virtualbox qt5-x11extras virtualbox-guest-iso
		dist_install virtualbox-ext-oracle
		depmod -a

		# Add the user to theg vboxusers group, so that USB will work.
		gpasswd -a $USERNAMEVAR vboxusers

		# Create the /media folder if it doesn't exist.
		if [ ! -d /media ]; then
			mkdir /media
			chmod 777 /media
		fi

	fi

	###############################################################################
	#######################        Thinkpad R61 Fixes      ########################
	###############################################################################
	# Perform thinkpad R61 specific fixes.
	if grep -iq "ThinkPad R61" "/sys/devices/virtual/dmi/id/product_version"; then
		#Fix thinkpad graphics corruption in GRUB
		sed -i 's/GRUB_GFXMODE=auto/GRUB_GFXMODE=1024x768/g' /etc/default/grub
		grub_update
	fi

elif [ "${MACHINEARCH}" = "armv7l" ]; then
	echo "ARM Software for Arch."

	#Install xorg
	dist_install xorg-server xorg-server-utils mesa-libgl xorg-xinit xterm mesa xf86-video-fbdev

	dist_install wget python networkmanager network-manager-applet ntfs-3g gptfdisk dosfstools alsa-utils btrfs-progs xfsprogs f2fs-tools
	systemctl enable NetworkManager

	# Install browsers
	dist_install midori

	# Omxplayer
	dist_install omxplayer ttf-freefont xclip youtube-dl

	# Reinstall iputils to fix ping
	pacman -S --noconfirm iputils

fi
