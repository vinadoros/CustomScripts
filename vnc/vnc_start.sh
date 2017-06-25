#!/bin/bash
# Derived from https://github.com/ConSol/docker-headless-vnc-container
# Exit on error.
set -e

USERNAMEVAR=user
USERGROUP=$(id -gn $USERNAMEVAR)
USERHOME="$(eval echo ~$USERNAMEVAR)"
[ -z $VNC_PW ] && VNC_PW="vncpassword"
[ -z $VNC_PORT ] && VNC_PORT=5901
[ -z $VNC_RESOLUTION ] && VNC_RESOLUTION="1280x1024"
[ -z $VNC_COL_DEPTH ] && VNC_COL_DEPTH=24
[ -z $DISPLAY ] && DISPLAY=":1"

# Add vnc startup.
mkdir -m 777 -p $USERHOME/.vnc
bash -c "cat >$USERHOME/.vnc/xstartup" <<'EOL'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec xfce4-session
EOL
chmod a+rwx $USERHOME/.vnc/xstartup

## write correct window size to chrome properties
VNC_RES_W=${VNC_RESOLUTION%x*}
VNC_RES_H=${VNC_RESOLUTION#*x}

# Write chromium init
echo "CHROMIUM_FLAGS='--no-sandbox --user-data-dir --window-size=$VNC_RES_W,$VNC_RES_H --window-position=0,0'" > $USERHOME/.chromium-browser.init

# Change vnc password
echo "Changing VNC Password."
su $USERNAMEVAR -c "(echo $VNC_PW && echo $VNC_PW) | vncpasswd"

# Set permissions for user folder
chown $USERNAMEVAR:$USERGROUP -R $USERHOME

# Start vncserver
vncserver -kill :1 || rm -rfv /tmp/.X*-lock /tmp/.X11-unix || echo "remove old vnc locks to be a reattachable container"
echo "Run vncserver"
# http://tigervnc.org/doc/vncserver.html
# http://tigervnc.org/doc/Xvnc.html
# The following command is for the official tigervnc binary from bintray.com
# su $USERNAMEVAR -c "vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -alwaysshared"
# The following command is for the tigervnc package in the ubuntu repositorities.
su $USERNAMEVAR -c "vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -alwaysshared -rfbport $VNC_PORT -localhost=no"
# TODO: Use supervisord to run vncserver
# Disable screensaver and power management
sleep 5
# Set xauthority so xset can find the display.
export XAUTHORITY=$USERHOME/.Xauthority
xset -dpms &
xset s noblank &
xset s off &
# Sleep forever
while true; do sleep 10; done
