#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

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

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi


###############################################################################
###############################        VNC      ###############################
###############################################################################
pacman -Syu --needed --noconfirm tigervnc
pacman -S --needed --noconfirm mate gnome-themes-standard

if [ ! -f /etc/vncpasswd ]; then
	echo "Enter a VNC password (stored in /etc/vncpasswd):"
	until vncpasswd /etc/vncpasswd
		do echo "Try again in 2 seconds."
		sleep 2
	done
	chmod 0444 /etc/vncpasswd
fi

if [ ! -f /etc/systemd/system/vncuser.service ]; then
	echo "Creating vncuser.service."
	bash -c "cat >>/etc/systemd/system/vncuser.service" <<EOL
[Unit]
Description=Remote desktop service as user (VNC)
After=syslog.target network.target

[Service]
Type=simple
User=$USERNAMEVAR
PAMName=login

# Clean any existing files in /tmp/.X11-unix environment
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :2 > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver :2 -geometry 1024x768 -fg -alwaysshared -rfbauth /etc/vncpasswd
ExecStop=/usr/bin/vncserver -kill :2
PIDFile=$USERHOME/.vnc/%H:2.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
fi

if [ ! -d $USERHOME/.vnc/ ]; then
	mkdir $USERHOME/.vnc/
	chown $USERNAMEVAR:users -R $USERHOME/.vnc/
	chmod 700 -R $USERHOME/.vnc/
fi



if [ ! -f $USERHOME/.vnc/xstartup ]; then
	echo "Creating $USERHOME/.vnc/xstartup."
	bash -c "cat >>$USERHOME/.vnc/xstartup" <<'EOL'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec mate-session
EOL
	chmod 777 $USERHOME/.vnc/xstartup
fi

<<COMMENT5
if [ ! -f /etc/systemd/system/vncroot.service ]; then
	echo "Creating vncroot.service."
	bash -c "cat >>/etc/systemd/system/vncroot.service" <<EOL
[Unit]
Description=Remote desktop service as root (VNC)
After=syslog.target network.target

[Service]
Type=simple
User=root
PAMName=login

# Clean any existing files in /tmp/.X11-unix environment
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :3 > /dev/null 2>&1 || :'
ExecStart=/usr/bin/vncserver :3 -geometry 1024x768 -fg -alwaysshared -rfbauth /etc/vncpasswd
ExecStop=/usr/bin/vncserver -kill :3
PIDFile=/root/.vnc/%H:3.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL
fi

if [ ! -d /root/.vnc/ ]; then
	mkdir /root/.vnc/
	chmod 700 -R /root/.vnc/
fi

if [ ! -f /root/.vnc/xstartup ]; then
	echo "Creating /root/.vnc/xstartup."
	bash -c "cat >>/root/.vnc/xstartup" <<'EOL'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec mate-session
EOL
	chmod 777 /root/.vnc/xstartup
fi
COMMENT5



