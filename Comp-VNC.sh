#!/bin/bash

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

# Set user folders.
if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
	export USERNAMEVAR=$SUDO_USER
elif [ "$USER" != "root" ]; then
	export USERNAMEVAR=$USER
else
	export USERNAMEVAR=$(id 1000 -un)
fi
export USERGROUP=$(id $USERNAMEVAR -gn)
export USERHOME=/home/$USERNAMEVAR

# Install tigervnc
if type yaourt; then
	yaourt -ASa --needed --noconfirm openbox xfce4-panel
elif type zypper; then
	zypper in -yl tigervnc autocutsel
elif type apt-get; then
	apt-get install -y tigervnc-standalone-server vnc4server openbox xfce4-panel autocutsel
elif type dnf; then
	dnf install -y tigervnc tigervnc-server openbox xfce4-panel
fi

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi


###############################################################################
###############################        VNC      ###############################
###############################################################################

# VNC Variables
VNCLOCATION="$(which x0vncserver)"
VNCPASSPATH="/etc"
VNCPASS="${VNCPASSPATH}/vncpasswd"
XHOSTLOCATION="$(which xhost)"
SDPATH="/etc/systemd/system"
X0SDSERVICE="vncxorg@.service"
VNCUSERSERVICE="vncuser.service"
# VNCUSERSOCKET="vncuser.socket"

if [ ! -d $USERHOME/.vnc/ ]; then
	mkdir $USERHOME/.vnc/
	chown $USERNAMEVAR:$USERGROUP -R $USERHOME/.vnc/
	chmod 700 -R $USERHOME/.vnc/
fi

echo "Creating $USERHOME/.vnc/xstartup."
bash -c "cat >$USERHOME/.vnc/xstartup" <<'EOL'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# Execute this session. Add more sessions as necessary to autoselect.
if type mate-session; then
	exec mate-session
elif type openbox-session; then
	exec openbox-session
fi
EOL
chmod a+rwx $USERHOME/.vnc/xstartup
chown $USERNAMEVAR:$USERGROUP -R $USERHOME/.vnc

# Configure openbox
if type openbox-session && type xfce4-panel; then
	mkdir -p $USERHOME/.config/openbox
	bash -c "cat >>$USERHOME/.config/openbox/autostart" <<'EOL'
xfce4-panel &
EOL
chown $USERNAMEVAR:$USERGROUP -R $USERHOME/.config/openbox
fi

# TODO Eliminate prompting for password at some point.
if [ ! -f "$VNCPASS" ]; then
	echo "Enter a VNC password (stored in $VNCPASS):"
	until vncpasswd "$VNCPASS"
		do echo "Try again in 2 seconds."
		sleep 2
	done
	chown $USERNAMEVAR:$USERGROUP "$VNCPASS"
	chmod 0444 "$VNCPASS"
fi

echo "Creating $SDPATH/$VNCUSERSERVICE."
bash -c "cat >$SDPATH/$VNCUSERSERVICE" <<EOL
[Unit]
Description=Remote desktop service as user (VNC)
After=syslog.target network.target

[Service]
Type=simple
User=$USERNAMEVAR
PAMName=login

# Clean any existing files in /tmp/.X11-unix environment
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :5 > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver :5 -geometry 1024x768 -fg -alwaysshared -rfbport 5905 -rfbauth "$VNCPASS" -auth ~/.Xauthority
ExecStop=/usr/bin/vncserver -kill :5
PIDFile=$USERHOME/.vnc/%H:5.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
echo "Run \"systemctl enable vncuser.service\" to enable vnc standalone client."

# echo "Creating $SDPATH/$VNCUSERSOCKET."
# bash -c "cat >$SDPATH/$VNCUSERSOCKET" <<EOL
# [Unit]
# Description=Remote desktop service as user (VNC) Socket
#
# [Socket]
# ListenStream=5905
#
# [Install]
# WantedBy=sockets.target
# EOL
# systemctl daemon-reload
# systemctl enable vncuser.socket

# Create user systemd service for x0vncserver.
user_systemd_service "vncx0user.service" <<EOL
[Unit]
Description=TigerVNC server for user session.

[Service]
Type=simple
ExecStart=${VNCLOCATION} -passwordfile ${VNCPASS} -rfbport 5900
Restart=always
RestartSec=10s
TimeoutStopSec=7s

[Install]
WantedBy=default.target
EOL

# Add autocutsel to xinitrc to enable clipboard sharing
if [ -d /etc/X11/xinit/xinitrc.d/ ]; then
	echo "Creating /etc/X11/xinit/xinitrc.d/40-autocutsel.sh."
	bash -c "cat >/etc/X11/xinit/xinitrc.d/40-autocutsel.sh" <<'EOL'
#!/bin/bash
autocutsel -fork &
EOL
	chmod 777 /etc/X11/xinit/xinitrc.d/40-autocutsel.sh
fi
