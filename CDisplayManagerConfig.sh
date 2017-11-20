#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/CGeneralFunctions.sh"

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
	export USERGROUP=$(id $USERNAMEVAR -gn)
	export USERHOME="$(eval echo ~$USERNAMEVAR)"
fi

# Set default VM guest variables
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0
[ -z $DMAUTO ] && DMAUTO=0

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

###############################################################################
#############################        LightDM      #############################
###############################################################################

# Set-up lightdm autologin
if [[ $(type -P lightdm) ]]; then
	if ! grep -i "^autologin" /etc/group; then
		groupadd autologin
	fi
	gpasswd -a $USERNAMEVAR autologin
fi

# Enable lightdm autologin for virtual machines.
if type lightdm && [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 || $DMAUTO = 1 ]]; then
	echo "Enabling lightdm autologin for $USERNAMEVAR."
	[ -f /etc/lightdm/lightdm.conf ] && sed -i 's/#autologin-user=/autologin-user='$USERNAMEVAR'/g' /etc/lightdm/lightdm.conf
	mkdir -p /etc/lightdm/lightdm.conf.d/
	echo -e "[SeatDefaults]\nautologin-user=$USERNAMEVAR" > /etc/lightdm/lightdm.conf.d/12-autologin.conf
fi

# Enable listing of users
if [ -f /etc/lightdm/lightdm.conf ]; then
	sed -i 's/#greeter-hide-users=false/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf
fi

# Create filename containing synergyc host.
HOSTFILE="/usr/local/bin/synhost.txt"
if [ ! -f "$HOSTFILE" ]; then
	echo "HostnameHere" >> "$HOSTFILE"
	chmod a+rwx "$HOSTFILE"
	echo "Be sure to change the hostname in $HOSTFILE."
fi

LDSTART="/usr/local/bin/ldstart.sh"
multilinereplace "$LDSTART" <<EOLXYZ
#!/bin/bash
echo "Executing \$0"

# https://wiki.freedesktop.org/www/Software/LightDM/CommonConfiguration/
# https://bazaar.launchpad.net/~lightdm-team/lightdm/trunk/view/head:/data/lightdm.conf

SERVER="\$(<$HOSTFILE)"

if [ -z \$DISPLAY ]; then
	echo "Setting variables for xvnc."
	DISPLAY=:0
fi

if type -p synergyc &> /dev/null && [[ "\$SERVER" != "HostnameHere" ]]; then
	echo "Starting Synergy client."
	synergyc "\$SERVER"
fi

if type -p x0vncserver &> /dev/null && [ -f /etc/vncpasswd ]; then
	echo "Starting vnc."
	x0vncserver -passwordfile /etc/vncpasswd -rfbport 5900 &
fi

# Don't run if gdm is running.
if type -p xset &> /dev/null && ! pgrep gdm &> /dev/null; then
	echo "Starting xset dpms."
	# http://shallowsky.com/linux/x-screen-blanking.html
	# http://www.x.org/releases/X11R7.6/doc/man/man1/xset.1.xhtml
	# Turn screen off in 60 seconds.
	xset s 60
	xset dpms 60 60 60
fi

exit 0
EOLXYZ

LDSTOP="/usr/local/bin/ldstop.sh"
multilinereplace "$LDSTOP" <<'EOLXYZ'
#!/bin/bash
echo "Executing $0"

# Kill synergy client.
if pgrep synergyc; then
	killall synergyc
fi

# Kill X VNC server.
if pgrep x0vncserver; then
	killall x0vncserver
fi

# Set xset parameters back to defaults.
if type -p xset &> /dev/null && ! pgrep gdm &> /dev/null; then
	xset s
fi

exit 0
EOLXYZ

# Run startup scripts
if [ -f /etc/lightdm/lightdm.conf ]; then
	# Uncomment lines
	sed -i '/^#display-setup-script=.*/s/^#//g' /etc/lightdm/lightdm.conf
	sed -i '/^#session-setup-script=.*/s/^#//g' /etc/lightdm/lightdm.conf
	# Add startup scripts to session
	sed -i "s@display-setup-script=.*@display-setup-script=$LDSTART@g" /etc/lightdm/lightdm.conf
	sed -i "s@session-setup-script=.*@session-setup-script=$LDSTOP@g" /etc/lightdm/lightdm.conf
elif [[ ! -f /etc/lightdm/lightdm.conf && -d /etc/lightdm/lightdm.conf.d/ ]]; then
	echo -e "[SeatDefaults]\ndisplay-setup-script=$LDSTART\nsession-setup-script=$LDSTOP" > /etc/lightdm/lightdm.conf.d/11-startup.conf
fi

###############################################################################
###############################        GDM      ###############################
###############################################################################

# GNOME screenblanking with lightdm (or rather, not GDM)
multilinereplace "/usr/local/bin/dpms-gnome.sh" <<"EOL"
#!/bin/bash

# Run xscreensaver if gnome-session is running, gdm is not running, and xscreensaver exists.
if pgrep gnome-session &> /dev/null && ! pgrep gdm &> /dev/null && type -p xscreensaver &> /dev/null; then
	echo "Start xscreensaver."
	xscreensaver -no-splash &
fi
EOL
# Screen blanks in 5 minutes.
multilinereplace "$USERHOME/.xscreensaver" <<"EOL"
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
multilinereplace "/etc/xdg/autostart/dpms-gnome.desktop" <<"EOL"
[Desktop Entry]
Name=Gnome DPMS Setting
Exec=/usr/local/bin/dpms-gnome.sh
Terminal=false
Type=Application
EOL

# Detect gdm folders
if [[ $(type -P gdm) || $(type -P gdm3) ]]; then
	if type -P gdm3; then
		GDMPATH="/var/lib/gdm3"
		GDMETCPATH="/etc/gdm3"
	elif type -P gdm; then
		GDMPATH="/var/lib/gdm"
		GDMETCPATH="/etc/gdm"
	fi
	GDMUID="$(id -u gdm)"
	GDMGID="$(id -g gdm)"

	# Enable gdm autologin for virtual machines. Does not currently work.
	if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 || $DMAUTO = 1 ]]; then
		echo "Enabling gdm autologin for $USERNAMEVAR."
		# https://afrantzis.wordpress.com/2012/06/11/changing-gdmlightdm-user-login-settings-programmatically/
		# Get dbus path for the user
		USER_PATH=$(dbus-send --print-reply=literal --system --dest=org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts.FindUserByName string:"$USERNAMEVAR")
		# Send the command over dbus to freedesktop accounts.
		dbus-send --print-reply --system --dest=org.freedesktop.Accounts $USER_PATH org.freedesktop.Accounts.User.SetAutomaticLogin boolean:true
		# https://hup.hu/node/114631
		# Can check options with following command:
		# dbus-send --system --dest=org.freedesktop.Accounts --print-reply --type=method_call $USER_PATH org.freedesktop.DBus.Introspectable.Introspect
		# qdbus --system org.freedesktop.Accounts $USER_PATH org.freedesktop.Accounts.User.AutomaticLogin
	fi

	# Pulseaudio gdm fix
	# http://www.debuntu.org/how-to-disable-pulseaudio-and-sound-in-gdm/
	# https://bbs.archlinux.org/viewtopic.php?id=202915
	if [[ -f /etc/pulse/default.pa ]]; then
		echo "Executing gdm pulseaudio fix."

		if [ ! -d "$GDMPATH/.config/pulse/" ]; then
			mkdir -p "$GDMPATH/.config/pulse/"
		fi

		cp /etc/pulse/default.pa "$GDMPATH/.config/pulse/default.pa"
		sed -i '/^load-module .*/s/^/#/g' "$GDMPATH/.config/pulse/default.pa"

		chown -R $GDMUID:$GDMGID "$GDMPATH/"
	fi

	#### Enable synergy and vnc in gdm ####
	# https://help.gnome.org/admin/gdm/stable/configuration.html.en
	# https://forums-lb.gentoo.org/viewtopic-t-1027688.html
	# https://bugs.gentoo.org/show_bug.cgi?id=553446
	# https://major.io/2008/07/30/automatically-starting-synergy-in-gdm-in-ubuntufedora/

	# Disable Wayland in GDM
	if [ -f "$GDMETCPATH/custom.conf" ]; then
		sed -i '/^#WaylandEnable=.*/s/^#//' "$GDMETCPATH/custom.conf"
		sed -i 's/^WaylandEnable=.*/WaylandEnable=false/g' "$GDMETCPATH/custom.conf"
	fi

	# Start xvnc and synergy
	multilinereplace "/usr/share/gdm/greeter/autostart/gdm_start.desktop" <<EOL
[Desktop Entry]
Type=Application
Name=GDM Startup
X-GNOME-Autostart-enabled=true
X-GNOME-AutoRestart=true
Exec=${LDSTART}
NoDisplay=true
EOL

	# Stop apps after login. Add this right after script declaration.
	if ! grep "^$LDSTOP" "$GDMETCPATH/PreSession/Default"; then
		sed -i "/#\!\/bin\/sh/a $LDSTOP" "$GDMETCPATH/PreSession/Default"
	fi

fi