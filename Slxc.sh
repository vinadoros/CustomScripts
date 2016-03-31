#!/bin/bash

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

set -e

while true; do
    read -p "1: Install/enable lxc. 2: Remove lxc. Enter 0 to do nothing. (0/1/2)" QU
    case $QU in

    [0]* )
    echo "You asked to do nothing."
	break;;

    [1]* )
    echo "You asked to install lxc."
	sudo pacman -Syu --needed lxc dnsmasq lua-filesystem lua-alt-getopt
	btrfsrmsubvol
	#~ sudo sed -i 's/#user = \"root\"/user = \"'$USERNAMEVAR'\"/g' /etc/libvirt/qemu.conf
	#~ #sudo sed -i 's/group=.*/group=\"users\"/g' /etc/libvirt/qemu.conf
	#~ sudo sed -i 's/#save_image_format = \"raw\"/save_image_format = \"xz"/g' /etc/libvirt/qemu.conf
	#~ sudo sed -i 's/#dump_image_format = \"raw\"/dump_image_format = \"xz"/g' /etc/libvirt/qemu.conf
	#~ sudo sed -i 's/#snapshot_image_format = \"raw\"/snapshot_image_format = \"xz"/g' /etc/libvirt/qemu.conf
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
