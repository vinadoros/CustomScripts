#!/bin/bash
# Derived from https://github.com/ConSol/docker-headless-vnc-container
### every exit != 0 fails the script
set -e

# should also source $STARTUPDIR/generate_container_user
# source $HOME/.bashrc
# Set current user in nss_wrapper
USER_ID=$(id -u)
GROUP_ID=$(id -g)
echo "USER_ID: $USER_ID, GROUP_ID: $GROUP_ID"

if [ x"$USER_ID" != x"0" ]; then

    NSS_WRAPPER_PASSWD=/tmp/passwd
    NSS_WRAPPER_GROUP=/etc/group

    cat /etc/passwd > $NSS_WRAPPER_PASSWD

    echo "default:x:${USER_ID}:${GROUP_ID}:Default Application User:${HOME}:/bin/bash" >> $NSS_WRAPPER_PASSWD

    export NSS_WRAPPER_PASSWD
    export NSS_WRAPPER_GROUP

    if [ -r /usr/lib/libnss_wrapper.so ]; then
        LD_PRELOAD=/usr/lib/libnss_wrapper.so
    elif [ -r /usr/lib64/libnss_wrapper.so ]; then
        LD_PRELOAD=/usr/lib64/libnss_wrapper.so
    else
        echo "no libnss_wrapper.so installed!"
        exit 1
    fi
    echo "nss_wrapper location: $LD_PRELOAD"
    export LD_PRELOAD
fi


## write correct window size to chrome properties
VNC_RES_W=${VNC_RESOLUTION%x*}
VNC_RES_H=${VNC_RESOLUTION#*x}

echo -e "\n------------------ update chromium-browser.init ------------------"
echo -e "\n... set window size $VNC_RES_W x $VNC_RES_H as chrome window size!\n"

echo "CHROMIUM_FLAGS='--no-sandbox --user-data-dir --window-size=$VNC_RES_W,$VNC_RES_H --window-position=0,0'" > $HOME/.chromium-browser.init

## resolve_vnc_connection
VNC_IP=$(ip addr show eth0 | grep -Po 'inet \K[\d.]+')

## change vnc password
echo -e "\n------------------ change VNC password  ------------------"
(echo $VNC_PW && echo $VNC_PW) | vncpasswd

## start vncserver
vncserver -kill :1 || rm -rfv /tmp/.X*-lock /tmp/.X11-unix || echo "remove old vnc locks to be a reattachable container"
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION
### disable screensaver and power management
xset -dpms &
xset s noblank &
xset s off &

/usr/bin/startxfce4 --replace > $HOME/wm.log &
sleep 1
cat $HOME/wm.log

## log connect options
echo -e "\n\n------------------ VNC environment started ------------------"
echo -e "\nVNCSERVER started on DISPLAY= $DISPLAY \n\t=> connect via VNC viewer with $VNC_IP:$VNC_PORT"
echo -e "\nnoVNC HTML client started:\n\t=> connect via http://$VNC_IP:$NO_VNC_PORT/?password=...\n"

if [[ $1 =~ -t|--tail-log ]]; then
    # if option `-t` or `--tail-log` block the execution and tail the VNC log
    echo -e "\n------------------ $HOME/.vnc/*$DISPLAY.log ------------------"
    tail -f $HOME/.vnc/*$DISPLAY.log
elif [ -z "$1" ] ; then
    echo -e "..."
else
    # unknown option ==> call command
    echo -e "\n\n------------------ EXECUTE COMMAND ------------------"
    echo "Executing command: '$@'"
    exec "$@"
fi
