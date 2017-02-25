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
		if type pacman; then
			sudo pacman -Syu --needed virt-manager ebtables dnsmasq qemu bridge-utils
			sudo systemctl enable libvirtd
			sudo systemctl start libvirtd
			sudo systemctl enable virtlogd
			sudo systemctl start virtlogd
			sudo gpasswd -a $USERNAMEVAR kvm
		elif type zypper; then
			sudo zypper in -l -y virt-manager libvirt
			sudo systemctl enable libvirtd
			sudo systemctl start libvirtd
		elif type apt-get; then
			sudo apt-get install -y virt-manager qemu-kvm ssh-askpass
			sudo gpasswd -a $USERNAMEVAR libvirtd
		elif type dnf; then
			echo "none"
		fi
		sudo sed -i 's/#user = \"root\"/user = \"'$USERNAMEVAR'\"/g' /etc/libvirt/qemu.conf
		#sudo sed -i 's/group=.*/group=\"users\"/g' /etc/libvirt/qemu.conf
		sudo sed -i 's/#save_image_format = \"raw\"/save_image_format = \"xz"/g' /etc/libvirt/qemu.conf
		sudo sed -i 's/#dump_image_format = \"raw\"/dump_image_format = \"xz"/g' /etc/libvirt/qemu.conf
		sudo sed -i 's/#snapshot_image_format = \"raw\"/snapshot_image_format = \"xz"/g' /etc/libvirt/qemu.conf
		# https://ask.fedoraproject.org/en/question/45805/how-to-use-virt-manager-as-a-non-root-user/
		[[ ! -d /etc/polkit-1/rules.d && -d /etc/polkit-1 ]] && sudo mkdir -p /etc/polkit-1/rules.d
		sudo bash -c "cat >/etc/polkit-1/rules.d/80-libvirt.rules" <<'EOL'
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" && subject.active && subject.isInGroup("wheel")) {
      return polkit.Result.YES;
  }
});
EOL

	break;;

	[2]* )
	echo "You asked to remove virt-manager."
	if type pacman; then
		sudo systemctl disable libvirtd
		sudo systemctl stop libvirtd
		sudo systemctl disable virtlogd
		sudo systemctl stop virtlogd
		sudo pacman -Rsn virt-manager ebtables dnsmasq qemu bridge-utils
		sudo pacman -Syu --needed gnu-netcat
	elif type zypper; then
		sudo systemctl disable libvirtd
		sudo systemctl stop libvirtd
		sudo zypper rm -u virt-manager libvirt
	elif type apt-get; then
		sudo apt-get --purge remove virt-manager qemu-kvm
	elif type dnf; then
		echo "none"
	fi
	sudo rm -f /etc/polkit-1/rules.d/80-libvirt.rules
	break;;

	* ) echo "Please input 0, 1 or 2.";;
    esac
done
