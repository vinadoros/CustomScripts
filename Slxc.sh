#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

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

btrfsrmsubvol () {
	MACHINESSUBVOL="/var/lib/machines/"
	if btrfs subvol show "$MACHINESSUBVOL" &> /dev/null; then
		echo "$MACHINESSUBVOL subvol detected. Deleting."
		btrfs subvol delete "$MACHINESSUBVOL"
	else
		echo "$MACHINESSUBVOL subvol not detected."
	fi
}

while true; do
    read -p "1: Install/enable lxc. 2: Remove lxc. Enter 0 to do nothing. (0/1/2)" QU
    case $QU in

    [0]* )
    echo "You asked to do nothing."
	break;;

    [1]* )
    echo "You asked to install lxc."
	pacman -Syu --needed lxc dnsmasq lua-filesystem lua-alt-getopt arch-install-scripts
	btrfsrmsubvol
	sed -i '/USE_LXC_BRIDGE="false"/s/^/#/g' /etc/default/lxc

	multilinereplace "/etc/lxc/default.conf" <<'EOLXYZ'
lxc.network.type=veth
lxc.network.link=lxcbr0
lxc.network.flags=up
lxc.network.name=eth0

lxc.mount.entry = tmpfs tmp tmpfs defaults
lxc.mount.entry = /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry = /dev/snd dev/snd none bind,optional,create=dir
lxc.mount.entry = /tmp/.X11-unix tmp/.X11-unix none bind,optional,create=dir
lxc.mount.entry = /dev/video0 dev/video0 none bind,optional,create=file

#lxc.network.ipv4=10.0.3.2
#lxc.network.ipv4.gateway=10.0.3.1
#lxc.hook.pre-start=${LXC_ROOTFS_PATH}/../script.sh
EOLXYZ

	# Set lxc path
	while [ ! -d "${LXCVMPATH}" ]; do
		read -p "Enter a path to store lxc VM (i.e. \"/mnt/RaidStorage/VMs\"): " LXCVMPATH
	done
	echo "VM path is $LXCVMPATH"
	echo "lxc.lxcpath = $LXCVMPATH" | sudo tee -a /etc/lxc/lxc.conf

	break;;

	[2]* )
	echo "You asked to remove lxc."
	systemctl disable lxc
	systemctl stop lxc
	btrfsrmsubvol
	pacman -Rsn lxc
	pacman -Rsn lua-filesystem
	pacman -Rsn lua-alt-getopt
	break;;

	* ) echo "Please input 0, 1 or 2.";;
    esac
done
