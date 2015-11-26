#!/bin/bash

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR="$SUDO_USER"
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR="$USER"
	else
		export USERNAMEVAR="$(id 1000 -un)"
	fi
	USERGROUP="$(id 1000 -gn)"
	USERHOME="/home/$USERNAMEVAR"
fi

while true; do
    read -p "1: Install/enable virt-manager. 2: Remove virt-mananger. Enter 0 to do nothing. (0/1/2)" QU
    case $QU in
    
    [0]* ) 
    echo "You asked to do nothing."
	break;;
    
    [1]* ) 
    echo "You asked to install virt-manager."
	sudo pacman -Syu --needed virt-manager ebtables dnsmasq qemu bridge-utils
	sudo sed -i 's/#user = \"root\"/user = \"'$USERNAMEVAR'\"/g' /etc/libvirt/qemu.conf
	#sudo sed -i 's/group=.*/group=\"users\"/g' /etc/libvirt/qemu.conf
	sudo sed -i 's/#save_image_format = \"raw\"/save_image_format = \"xz"/g' /etc/libvirt/qemu.conf
	sudo sed -i 's/#dump_image_format = \"raw\"/dump_image_format = \"xz"/g' /etc/libvirt/qemu.conf
	sudo sed -i 's/#snapshot_image_format = \"raw\"/snapshot_image_format = \"xz"/g' /etc/libvirt/qemu.conf
	sudo systemctl enable libvirtd
	sudo systemctl start libvirtd
	sudo gpasswd -a $USERNAMEVAR kvm
	break;;
	
	[2]* ) 
	echo "You asked to remove virt-manager."
	sudo systemctl disable libvirtdarch
	sudo systemctl stop libvirtd
	sudo pacman -Rsn virt-manager ebtables dnsmasq qemu bridge-utils
	sudo pacman -Syu --needed gnu-netcat
	break;;
	
	* ) echo "Please input 0, 1 or 2.";;
    esac
done
