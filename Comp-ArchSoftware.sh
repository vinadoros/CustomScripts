#!/bin/bash

set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

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

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Install software

# Install apacman (allows installation of packages using root).
if ! pacman -Q "apacman" &>/dev/null; then
	pacman -S --needed --noconfirm binutils ca-certificates curl fakeroot file grep jshon sed tar wget
	cd /tmp
	curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/apacman.tar.gz
	tar zxvf apacman.tar.gz
	chmod a+rwx -R apacman
	cd apacman
	su nobody -s /bin/bash <<'EOL'
		makepkg --noconfirm -s
EOL
	pacman -U --noconfirm ./apacman-*.pkg.tar.xz
	cd ..
	rm -f apacman.tar.gz
	rm -rf ./apacman
fi
apacman -S --ignorearch --noconfirm --needed apacman-deps

# Install yaourt.
apacman -S --ignorearch --noconfirm --needed package-query yaourt

# Install randomness generator
pacman -S --needed --noconfirm haveged
systemctl enable haveged

# Make sure .gnupg folder exists for root
if [ ! -d /root/.gnupg ]; then
	echo "Creating /root/.gnupg folder."
	mkdir -p /root/.gnupg
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

# Update system
pacman -Syu --needed --noconfirm

# Add groups to current user
usermod -aG lp,network,video,audio,storage,scanner,power,disk,sys,games,optical,avahi,systemd-journal $USERNAMEVAR

# Remove xnoise, if it exists
if (pacman -Q xnoise &>/dev/null); then
	pacman -Rs --noconfirm xnoise
fi

# Setup devel stuff
pacman -S --needed --noconfirm rsync base-devel


###############################################################################
########################        Display Managers      #########################
###############################################################################

# Set up lightdm
function lightdmscript(){
	pacman -S --needed --noconfirm lightdm
	systemctl enable -f lightdm
}

# Set up dpms settings for lightdm.
function lightdmdpms(){
	pacman -Syu --needed --noconfirm xscreensaver
	if ! grep -iq "xscrnsvr.sh" /etc/lightdm/lightdm.conf; then
		echo "Setting xscreensaver values for lightdm"
		sudo sed -i '/^\[SeatDefaults\]$/ s:$:\ndisplay-setup-script=/usr/local/bin/xscrnsvr.sh:' /etc/lightdm/lightdm.conf	
	fi
	if [ ! -f /usr/local/bin/xscrnsvr.sh ]; then
		echo "Creating xscrnsvr.sh."
		sudo bash -c "cat >/usr/local/bin/xscrnsvr.sh" <<'EOL'
#!/bin/bash
sleep 10
( /usr/bin/xscreensaver -no-splash -display :0.0 ) &
exit
EOL
		sudo chmod 777 /usr/local/bin/xscrnsvr.sh
	fi
	if [ ! -f /etc/xdg/autostart/xscreensaver.desktop ]; then
		echo "Creating xscreensaver.desktop."
		sudo bash -c "cat >/etc/xdg/autostart/xscreensaver.desktop" <<'EOL'
[Desktop Entry]
Name=xscreensaver
Exec=/usr/local/bin/xscrnsvr.sh
Type=Application
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOL
		sudo chmod 644 /etc/xdg/autostart/xscreensaver.desktop
	fi	
	if [ ! -f $USERHOME/.xscreensaver ]; then
		echo "Creating ~/.xscreensaver for $USERNAMEVAR."
		bash -c "cat >$USERHOME/.xscreensaver" <<'EOL'
timeout:	0:05:00
cycle:		0:10:00
lock:		False
lockTimeout:	0:00:00
passwdTimeout:	0:00:30
dpmsEnabled:	True
dpmsQuickOff:	True
dpmsStandby:	0:05:00
dpmsSuspend:	0:05:00
dpmsOff:	0:05:00
mode:		blank
selected:	211
EOL
		chown -R $USERNAMEVAR:$USERGROUP $USERHOME/.xscreensaver
	fi
	if [ ! -f ~/.xscreensaver ]; then
		echo "Creating ~/.xscreensaver for root."
		bash -c "cat >~/.xscreensaver" <<'EOL'
timeout:	0:05:00
cycle:		0:10:00
lock:		False
lockTimeout:	0:00:00
passwdTimeout:	0:00:30
dpmsEnabled:	True
dpmsQuickOff:	True
dpmsStandby:	0:05:00
dpmsSuspend:	0:05:00
dpmsOff:	0:05:00
mode:		blank
selected:	211
EOL
	fi
}


# Case for SETDM variable.
case $SETDM in
[1]* ) 
	echo "Setting up SDDM."
	pacman -S --needed --noconfirm sddm
	systemctl enable -f sddm
	if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 ]]; then
		if [ ! -f /etc/sddm.conf ]; then
			touch /etc/sddm.conf
		fi
		if ! grep -iq "Autologin" /etc/sddm.conf; then
			echo "Setting up Autologin."
			bash -c "cat >/etc/sddm.conf" <<EOL
		
[Autologin]
User=$USERNAMEVAR
Session=plasma.desktop
EOL
		fi
	fi
	;;

[2]* ) 
	echo "Setting up lightdm with GTK greeter."
	lightdmscript
	pacman -S --needed --noconfirm lightdm lightdm-gtk-greeter
	sed -i 's/greeter-session=.*$/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf
	;;
	
[3]* ) 
	echo "Setting up GDM."
	pacman -S --needed --noconfirm gdm
	systemctl enable -f gdm
	;;
	
[4]* ) 
	echo "Setting up lightdm with KDE greeter."
	lightdmscript
	pacman -S --needed --noconfirm lightdm lightdm-kde-greeter
	sed -i 's/greeter-session=.*$/greeter-session=lightdm-kde-greeter/g' /etc/lightdm/lightdm.conf
	;;

* ) echo "Not changing display manager settings."
	;;
esac


###############################################################################
######################        Desktop Environments      #######################
###############################################################################

# Case for SETDE variable. 0=do nothing, 1=KDE, 2=cinnamon
case $SETDE in
[1]* )
	# Install KDE
	echo "Installing KDE."
	pacman -S --needed --noconfirm drkonqi kde-gtk-config kdeplasma-addons khelpcenter kinfocenter kio-extras kscreen ksysguard kwrited oxygen oxygen-cursors plasma-desktop plasma-nm plasma-workspace-wallpapers sni-qt breeze-kde4
	if [ "${MACHINEARCH}" == "x86_64" ]; then
		pacman -S --needed --noconfirm lib32-sni-qt
	fi
	#apacman -S --needed --noconfirm libappindicator-gtk2 libappindicator-gtk3 
	# KDE Software
	if pacman -Q | grep -iq "khelpcenter"; then
		pacman -Rdd --noconfirm khelpcenter
	fi
	pacman -S --needed --noconfirm kate kdebase-dolphin konsole konsolepart4 ruby
	apacman -S --ignorearch --noconfirm --needed kde-servicemenus-rootactions
	pacman -S --needed --noconfirm kdebase-kwrite kdegraphics-okular ebook-tools kdeutils-ark unzip zip p7zip unrar
	;;

[2]* ) 
	# Install cinnamon
	echo "Installing Cinnamon."
	pacman -S --needed --noconfirm cinnamon nemo-fileroller nemo-preview nemo-share evince eog baobab gnome-calculator gnome-font-viewer gnome-disk-utility gnome-icon-theme gnome-system-log gnome-system-monitor gnome-terminal totem vino file-roller cdrkit lrzip unace unrar gnome-color-manager gedit gnome-clocks seahorse gufw xdg-utils gnome-logs
	;;
	
[3]* ) 
	# Install GNOME
	echo "Installing GNOME."
	pacman -S --needed --noconfirm gnome file-roller cdrkit lrzip unace unrar gedit gnome-clocks seahorse gufw gnome-tweak-tool xdg-utils gnome-logs dconf-editor gpaste
	# Install gnome shell extensions and misc apps
	apacman -S --ignorearch --noconfirm --needed gnome-shell-extension-dash-to-dock-git gnome-shell-extension-topicons gnome-shell-extension-mediaplayer-git
	apacman -S --ignorearch --noconfirm --needed gnome-shell-extension-volume-mixer-git
	
	if [ $SETDM != 3 ] && [ $SETDM != 0 ]; then
		lightdmdpms
	fi
	
	;;
	
[4]* ) 
	# Install XFCE
	echo "Installing XFCE."
	pacman -S --needed --noconfirm xfce4 xfce4-goodies
	# Install xfce notification for volume and whisker menu
	apacman -S --ignorearch --noconfirm --needed xfce4-whiskermenu-plugin xfce4-volumed
	;;
	
[5]* ) 
	# Install MATE
	echo "Installing MATE."
	pacman -S --needed --noconfirm mate xdg-user-dirs-gtk gnome-themes-standard gnome-keyring seahorse dconf-editor
	# MATE Extras
	pacman -S --needed --noconfirm atril caja-gksu caja-open-terminal caja-share engrampa eom gnome-calculator mate-applets mate-media mate-netspeed mate-power-manager mate-sensors-applet mate-system-monitor mate-terminal mate-utils mozo pluma unrar mate-screensaver
	
	#MATE gtk3
	#pacman -S --needed --noconfirm mate-gtk3 xdg-user-dirs-gtk gnome-themes-standard gnome-keyring seahorse dconf-editor
	# MATE gtk3 Extras
	#pacman -S --needed --noconfirm atril-gtk3 caja-gksu-gtk3 caja-open-terminal-gtk3 caja-share-gtk3 engrampa-gtk3 eom-gtk3 gnome-calculator mate-applets-gtk3 mate-media-gtk3 mate-netspeed-gtk3 mate-power-manager-gtk3 mate-sensors-applet-gtk3 mate-system-monitor-gtk3 mate-terminal-gtk3 mate-utils-gtk3 mozo-gtk3 pluma-gtk3 unrar mate-screensaver-gtk3
	
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
	apacman -S --ignorearch --noconfirm numix-circle-icon-theme-git
fi

# AV Software
pacman -S --needed --noconfirm gst-libav gst-plugins-base gst-plugins-bad gst-plugins-good gst-plugins-ugly
# Pulseaudio
pacman -S --needed --noconfirm pavucontrol paprefs pulseaudio pulseaudio-alsa pulseaudio-gconf pulseaudio-zeroconf
# Bluetooth
pacman -S --needed --noconfirm bluez bluez-firmware bluez-hid2hci bluez-libs bluez-utils pulseaudio-bluetooth

pacman -S --needed --noconfirm geany geany-plugins
pacman -S --needed --noconfirm firefox firefox-i18n-en-us 
pacman -S --needed --noconfirm leafpad gnome-disk-utility gparted p7zip unrar gvfs-smb gvfs-gphoto2 gvfs-goa gvfs-mtp gvfs-google gvfs-nfs libmtp systemd-ui meld
# System monitoring programs
pacman -S --needed --noconfirm iotop powertop jnettop nethogs
# Catfish search software
pacman -S --needed --noconfirm catfish findutils mlocate pinot antiword catdoc poppler djvulibre unrtf

# Install software for live computer.
if [[ $VBOXGUEST = 0 && $QEMUGUEST = 0 && $VMWGUEST = 0 ]]; then
	# Audio/video playback
	pacman -S --needed --noconfirm audacious vlc
fi

# Install avahi 
pacman -S --needed --noconfirm avahi nss-mdns pygtk python2-dbus
systemctl enable avahi-daemon.service
usermod -aG avahi $USERNAMEVAR

# Install samba and winbind
pacman -S --noconfirm --needed samba
systemctl enable smbd
systemctl enable nmbd
systemctl enable winbindd

# Install fish shell
pacman -S --needed --noconfirm fish

# Setup ssh
pacman -S --needed --noconfirm openssh xorg-xauth tmux
systemctl enable sshd

# NTP configuration
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Install syncthing
pacman -S --noconfirm --needed syncthing syncthing-gtk
systemctl enable syncthing@$USERNAMEVAR

# Install pamac
apacman -S --ignorearch --needed --noconfirm pamac-aur

# cron script to clean pacman cache weekly
if type -p fcrontab &> /dev/null; then
	grepcheckadd "&b 0 0 * * 6 \"pacman -Sc --noconfirm\"" "pacman -Sc --noconfirm" "/var/spool/fcron/root.orig"
	grepcheckadd "&b 0 0 * * 0 \"pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm\"" "pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm" "/var/spool/fcron/root.orig"
	fcrontab -z
fi
if [ -d "/etc/cron.weekly" ]; then
	echo "Adding pacman statements to cron."
	multilinereplace "/etc/cron.weekly/pacclean" <<'EOL'
#!/bin/bash
echo "Executing $0"
pacman -Sc --noconfirm
pacman -Sc --cachedir=/var/cache/apacman/pkg --noconfirm
EOL
fi

# For x86_64 and i686 only
if [ "${MACHINEARCH}" != "armv7l" ]; then
	echo "i686 and x86_64 Software for Arch."
	
	#Setup x2go
	pacman -S --needed --noconfirm x2goserver x2goclient
	x2godbadmin --createdb
	systemctl enable x2goserver

	# Cups-pdf configuration
	pacman -S --noconfirm --needed cups-pdf
	systemctl enable org.cups.cupsd.service
	systemctl restart org.cups.cupsd.service
	if ! grep -iq "Desktop" /etc/cups/cups-pdf.conf; then
		echo "Out ${USERHOME}/Desktop" | tee -a /etc/cups/cups-pdf.conf
	fi
	# Set up a virtual printer named cups-pdf, set the resolution and page size.
	until lpadmin -p cups-pdf -v cups-pdf:/ -E -P /usr/share/cups/model/CUPS-PDF.ppd
		do echo "Try again in 2 seconds."
		sleep 2
	done
	lpadmin -p cups-pdf -o Resolution=600dpi
	lpadmin -p cups-pdf -o PageSize=Letter
	
	# Install laptop mode tools
	pacman -S --needed --noconfirm tlp smartmontools ethtool
	systemctl enable tlp
	systemctl enable tlp-sleep
	
	# Install systemd-swap
	#~ pacman -S --needed --noconfirm systemd-swap
	#~ systemctl enable systemd-swap
	
	# Install reflector and sort mirrors for speed. Install service which loads on bootup.
	pacman -S --needed --noconfirm reflector
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
	pacman -Syu --needed --noconfirm

	# Libreoffice
	pacman -S --needed --noconfirm libreoffice-fresh hunspell hunspell-en hyphen hyphen-en libmythes mythes-en

	# Email
	pacman -S --needed --noconfirm thunderbird thunderbird-i18n-en-us

	# Flash
	pacman -S --needed --noconfirm flashplugin

	###############################################################################
	######################       Live Computer Section      #######################
	###############################################################################
	# Install software for live computer.
	if [[ $VBOXGUEST = 0 && $QEMUGUEST = 0 && $VMWGUEST = 0 ]]; then
		# Banshee
		pacman -S --needed --noconfirm vlc banshee
		# Wine
		pacman -S --needed --noconfirm wine alsa-lib alsa-plugins cups dosbox giflib lcms2 libcl libjpeg-turbo libldap libpng libpulse libxcomposite libxinerama libxml2 libxslt mpg123 ncurses openal samba v4l-utils wine_gecko wine-mono playonlinux
		if [ $(uname -m) == "x86_64" ]; then
			pacman -S --needed --noconfirm lib32-alsa-lib lib32-alsa-plugins lib32-giflib lib32-gnutls lib32-lcms2 lib32-libcl lib32-libjpeg-turbo lib32-libldap lib32-libpng lib32-libpulse lib32-libxcomposite lib32-libxinerama lib32-libxml2 lib32-libxslt lib32-mpg123 lib32-ncurses lib32-openal lib32-v4l-utils lib32-sdl
		fi
	fi

	# MS and other Fonts
	apacman -S --ignorearch --needed --noconfirm ttf-ms-fonts ttf-vista-fonts

	# Install google-chrome and remove chromium
	apacman -S --ignorearch --needed --noconfirm google-chrome
	if (pacman -Q chromium &>/dev/null); then
		pacman -Rs --noconfirm chromium
	fi

	###############################################################################
	#########################       Virtualbox Host      ##########################
	###############################################################################
	# Install virtualbox host
	if [[ $VBOXGUEST = 0 && $QEMUGUEST = 0 && $VMWGUEST = 0 ]]; then
		pacman -S --needed --noconfirm virtualbox-host-modules virtualbox virtualbox-guest-iso
		apacman -S --ignorearch --needed --noconfirm virtualbox-ext-oracle
		depmod -a
		
		# Add the user to theg vboxusers group, so that USB will work.
		gpasswd -a $USERNAMEVAR vboxusers
		
		# Create the /media folder if it doesn't exist.
		if [ ! -d /media ]; then
			mkdir /media
			chmod 777 /media
		fi
		
		# Have the kernel modules load on startup, which is required by vbox.
		if [ ! -f /etc/modules-load.d/virtualbox.conf ]; then
			bash -c "cat >>/etc/modules-load.d/virtualbox.conf" <<EOL
vboxdrv
vboxpci
vboxnetadp
vboxnetflt
EOL
		fi
		
	fi

	###############################################################################
	#######################        Thinkpad R61 Fixes      ########################
	###############################################################################
	# Perform thinkpad R61 specific fixes.
	if grep -iq "ThinkPad R61" "/sys/devices/virtual/dmi/id/product_version"; then
		#Fix thinkpad graphics corruption in GRUB
		sed -i 's/GRUB_GFXMODE=auto/GRUB_GFXMODE=1024x768/g' /etc/default/grub
		if [ -f /etc/grub.d/30_os-prober ]; then
			sudo chmod a-x /etc/grub.d/30_os-prober
		fi
		grub-mkconfig -o /boot/grub/grub.cfg
		if [ -f /etc/grub.d/30_os-prober ]; then
			sudo chmod a+x /etc/grub.d/30_os-prober
		fi
		
		if [ ! -f /etc/X11/xorg.conf.d/20-intel.conf ]; then
			bash -c "cat >>/etc/X11/xorg.conf.d/20-intel.conf" <<'EOL'
Section "Device"
Identifier  "Intel Graphics"
Driver      "intel"
Option      "AccelMethod"  "glamor"
EndSection
EOL
		fi
	fi

	# Install areca backup
	if pacman -Q jre8-openjdk-headless-infinality &> /dev/null; then
		pacman -Rdd --noconfirm jre8-openjdk-headless-infinality jre8-openjdk-infinality
	fi
	pacman -S --noconfirm --needed jre8-openjdk
	archlinux-java fix
	apacman -S --noconfirm --needed areca-bin


elif [ "${MACHINEARCH}" = "armv7l" ]; then
	echo "ARM Software for Arch."
	
	#Install xorg
	pacman -S --needed --noconfirm xorg-server xorg-server-utils mesa-libgl xorg-xinit xterm mesa xf86-video-fbdev

	pacman -S --needed --noconfirm wget python networkmanager ntfs-3g gptfdisk dosfstools ntp alsa-utils btrfs-progs xfsprogs f2fs-tools
	systemctl enable NetworkManager
	
	# Install browsers
	pacman -S --needed --noconfirm midori

	# Omxplayer
	pacman -S --needed --noconfirm omxplayer ttf-freefont xclip youtube-dl

	# Reinstall iputils to fix ping
	pacman -S --noconfirm iputils

	# Watchdog
	pacman -S --needed --noconfirm watchdog
	systemctl enable watchdog
	echo "bcm2708_wdog" > /etc/modules-load.d/bcm2708_wdog.conf
	
fi

