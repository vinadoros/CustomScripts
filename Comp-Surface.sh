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

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Setup surface apps
dist_install iio-sensor-proxy onboard

# Autostarts
cp /usr/share/applications/onboard.desktop $USERHOME/.config/autostart/

# Xorg fixes
if [ ! -d /etc/X11/xorg.conf.d/ ]; then
	mkdir -p /etc/X11/xorg.conf.d/
	chmod a+r /etc/X11/xorg.conf.d/
fi
# This is to enable volume up and down buttons in xorg.
bash -c "cat >>/etc/X11/xorg.conf.d/50-surface.conf" <<'EOL'
Section "InputClass"
        Identifier "MICROSOFT SAM"
        MatchDevicePath "/dev/input/event*"
        Driver "evdev"
        Option "vendor" "045e"
        Option "product" "0799"
EndSection
EOL

RANDOMSTRING=$( date | sha1sum | fold -w6 | head -n1 )
TEMPFOLDER="mnt-${RANDOMSTRING}"

# Grub script
multilinereplace "/usr/local/bin/grubboot.sh" <<'EOL'
#!/bin/bash
read -p "Enter a grub number (0 is 1st entry):" GRUBNUMBER
sudo grub-reboot $GRUBNUMBER
EOL

# Grub Desktop entry
multilinereplace "$USERHOME/Desktop/grub-boot.desktop" <<"EOL"
[Desktop Entry]
Name=Grub Boot
Exec=/usr/local/bin/grubboot.sh
Terminal=true
Type=Application
EOL

# DPMS Desktop entry
multilinereplace "$USERHOME/Desktop/surface-dpms.desktop" <<"EOL"
[Desktop Entry]
Name=Surface DPMS
Exec=/usr/local/bin/turnoffscreen.sh
Terminal=false
Type=Application
EOL

# Gnome Settings
if type -p gnome-session &> /dev/null; then
  #Onboard extension
  ONBOARDEXTFOLDER="onboard@simon.schumann.web.de"
  git clone https://github.com/schuhumi/gnome-shell-extension-onboard-integration "$TEMPFOLDER"
  cd "$TEMPFOLDER"
  mkdir -p "/usr/share/gnome-shell/extensions/$ONBOARDEXTFOLDER/"
  install -Dm644 "src/metadata.json" "/usr/share/gnome-shell/extensions/$ONBOARDEXTFOLDER/metadata.json"
  install -m644 "src/extension.js" "/usr/share/gnome-shell/extensions/$ONBOARDEXTFOLDER/extension.js"
  install -m644 "src/stylesheet.css" "/usr/share/gnome-shell/extensions/$ONBOARDEXTFOLDER/stylesheet.css"
  cd ..
  rm -rf "$TEMPFOLDER"

	su $USERNAMEVAR -s /bin/bash <<'EOL'
  # Enable the extension
  gsettings set org.gnome.shell enabled-extensions "['places-menu@gnome-shell-extensions.gcampax.github.com', 'window-list@gnome-shell-extensions.gcampax.github.com', 'activities-config@nls1729', 'dash-to-dock@micxgx.gmail.com', 'AdvancedVolumeMixer@harry.karvonen.gmail.com', 'GPaste@gnome-shell-extensions.gnome.org', 'mediaplayer@patapon.info', 'user-theme@gnome-shell-extensions.gcampax.github.com', 'shell-volume-mixer@derhofbauer.at', 'onboard@simon.schumann.web.de', 'TopIcons@phocean.net']"

  # Gsettings
  gsettings set org.gnome.settings-daemon.peripherals.mouse locate-pointer true
  gsettings set org.gnome.desktop.interface text-scaling-factor 1.1

	# Suspend surface on battery.
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 1200
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 600
	gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type suspend

	# Workaround for GNOME suspending Surface when idle.
	gsettings set org.gnome.desktop.session idle-delay 0

EOL
fi

# Screen blanks in 3 minutes.
multilinereplace "$USERHOME/.xscreensaver" <<"EOL"
timeout:	0:03:00
cycle:		0:10:00
lock:		False
lockTimeout:	0:00:00
passwdTimeout:	0:00:30
dpmsEnabled:	True
dpmsQuickOff:	True
dpmsStandby:	0:03:00
dpmsSuspend:	0:03:00
dpmsOff:	0:03:00
mode:		blank
selected:	211
EOL

# Use xscreensaver, since GNOME suspends Surface when idle.
multilinereplace "/etc/xdg/autostart/surface-xscr.desktop" <<"EOL"
[Desktop Entry]
Name=Surface Xscreensaver
Exec=xscreensaver -no-splash
Terminal=false
Type=Application
EOL
