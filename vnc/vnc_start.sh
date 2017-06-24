#!/bin/bash
# Derived from https://github.com/ConSol/docker-headless-vnc-container
# Exit on error.
set -e

USERNAMEVAR=user
USERGROUP=$(id -gn $USERNAMEVAR)
USERHOME="$(eval echo ~$USERNAMEVAR)"

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

## resolve_vnc_connection
VNC_IP=$(ip addr show eth0 | grep -Po 'inet \K[\d.]+')

# Change vnc password
echo "Changing VNC Password."
su $USERNAMEVAR -c "(echo $VNC_PW && echo $VNC_PW) | vncpasswd"

# Set permissions for user folder
chown $USERNAMEVAR:$USERGROUP -R $USERHOME

## start vncserver
vncserver -kill :1 || rm -rfv /tmp/.X*-lock /tmp/.X11-unix || echo "remove old vnc locks to be a reattachable container"
echo "Run vncserver"
# TODO: Use supervisord to run vncserver
su $USERNAMEVAR -c "vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -alwaysshared"
### disable screensaver and power management
sleep 5
xset -dpms &
xset s noblank &
xset s off &
# Sleep forever
while true; do sleep 10; done
