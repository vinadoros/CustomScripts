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

# Install tigervnc
dist_install tigervnc

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
VNCPASSPATH="${USERHOME}/.vnc"
VNCPASS="${VNCPASSPATH}/passwd"
XHOSTLOCATION="$(which xhost)"
SDPATH="/etc/systemd/system"
X0SDSERVICE="vncxorg@.service"
VNCUSERSERVICE="vncuser.service"

if [ ! -d $USERHOME/.vnc/ ]; then
	mkdir $USERHOME/.vnc/
	chown $USERNAMEVAR:$USERGROUP -R $USERHOME/.vnc/
	chmod 700 -R $USERHOME/.vnc/
fi

if [ ! -f $USERHOME/.vnc/xstartup ]; then
	echo "Creating $USERHOME/.vnc/xstartup."
	bash -c "cat >>$USERHOME/.vnc/xstartup" <<'EOL'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# Execute this session. Edit if MATE is not present on system.
exec mate-session
EOL
	chmod 777 $USERHOME/.vnc/xstartup
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
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :2 > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver :2 -geometry 1024x768 -fg -alwaysshared -rfbauth "$VNCPASS" -auth ~/.Xauthority
ExecStop=/usr/bin/vncserver -kill :2
PIDFile=$USERHOME/.vnc/%H:2.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
echo "Run \"systemctl enable vncuser.service\" to enable vnc standalone client."

echo "Creating $SDPATH/$X0SDSERVICE."
bash -c "cat >$SDPATH/$X0SDSERVICE" <<EOL
[Unit]
Description=TigerVNC server for connecting to display %i
Requires=graphical.target
After=network.target nss-lookup.target network-online.target graphical.target

[Service]
Type=simple
Environment="DISPLAY=:%i"
ExecStartPre=${XHOSTLOCATION} +localhost
ExecStart=${VNCLOCATION} -display :%i -passwordfile ${VNCPASS}
Restart=always
RestartSec=10s
TimeoutStopSec=7s
User=${USERNAMEVAR}

[Install]
WantedBy=graphical.target
EOL
systemctl daemon-reload
echo "Run \"systemctl enable vncxorg@0.service\" to enable vnc xorg client."
