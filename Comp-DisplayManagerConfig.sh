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
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
	USERGROUP=$(id 1000 -gn)
	USERHOME=/home/$USERNAMEVAR
fi

# Set default VM guest variables
[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0
[ -z $LIGHTDMAUTO ] && LIGHTDMAUTO=0

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

###############################################################################
#############################        LightDM      #############################
###############################################################################

# Set-up lightdm autologin
if [ -f /etc/systemd/system/display-manager.service ] && ls -la /etc/systemd/system/display-manager.service | grep -iq "lightdm"; then
	if ! grep -i "^autologin" /etc/group; then
		groupadd autologin
	fi
	gpasswd -a $USERNAMEVAR autologin
fi

# Enable lightdm autologin for virtual machines.
if [[ $VBOXGUEST = 1 || $QEMUGUEST = 1 || $VMWGUEST = 1 || $LIGHTDMAUTO = 1 ]] && [ -f /etc/lightdm/lightdm.conf ]; then
	echo "Enabling lightdm autologin for $USERNAMEVAR."
	sed -i 's/#autologin-user=/autologin-user='$USERNAMEVAR'/g' /etc/lightdm/lightdm.conf
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

if type -p synergyc &> /dev/null && [[ "\$SERVER" != "HostnameHere" ]]; then
	echo "Starting Synergy client."
	synergyc "\$SERVER"
fi

if type -p x0vncserver &> /dev/null && [ -f $USERHOME/.vnc/passwd ]; then
	echo "Starting vnc."
	x0vncserver -passwordfile $USERHOME/.vnc/passwd &
fi

if type -p xset &> /dev/null; then
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
if type -p xset &> /dev/null; then
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

# Pulseaudio gdm fix
# http://www.debuntu.org/how-to-disable-pulseaudio-and-sound-in-gdm/
# https://bbs.archlinux.org/viewtopic.php?id=202915
if [[ $(type -P gdm) || $(type -P gdm3) && -f /etc/pulse/default.pa ]]; then
	echo "Executing gdm pulseaudio fix."
	set +eu
	if type -P gdm3; then
		GDMUID="$(id -u Debian-gdm)"
		GDMGID="$(id -g Debian-gdm)"
		GDMPATH="/var/lib/gdm3"
	elif type -P gdm; then
		GDMUID="$(id -u gdm)"
		GDMGID="$(id -g gdm)"
		GDMPATH="/var/lib/gdm"
	fi
	set -eu

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
sed -i '/^#WaylandEnable=.*/s/^#//' "/etc/gdm/custom.conf"
sed -i 's/^WaylandEnable=.*/WaylandEnable=false/g' "/etc/gdm/custom.conf"

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

# Stop apps after login
grepadd "$LDSTOP" "/etc/gdm/PreSession/Default"
