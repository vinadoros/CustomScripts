#!/bin/bash

# Set user folders if they don't exist.
if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
	export USERNAMEVAR="$SUDO_USER"
elif [ "$USER" != "root" ]; then
	export USERNAMEVAR="$USER"
else
	export USERNAMEVAR="$(id 1000 -un)"
fi
USERGROUP="$(id $USERNAMEVAR -gn)"
USERHOME="/home/$USERNAMEVAR"

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
			sudo usermod -aG kvm $USERNAMEVAR
		elif type zypper; then
			sudo zypper in -l -y virt-manager libvirt
			sudo systemctl enable libvirtd
			sudo systemctl start libvirtd
		elif type apt-get; then
			sudo apt-get install -y virt-manager qemu-kvm ssh-askpass
			sudo usermod -aG libvirt $USERNAMEVAR
			sudo usermod -aG libvirt-qemu $USERNAMEVAR
		elif type dnf; then
			sudo dnf install -y @virtualization
			sudo systemctl enable libvirtd
			sudo systemctl start libvirtd
			sudo usermod -aG libvirt $USERNAMEVAR
		fi

		# Set network info
		sudo virsh net-autostart default
		sudo virsh net-start default

		# Set default storage location
		while true; do
			echo "Enter a path for VM images. (i.e. \"/mnt/Path here\")"
			read -p "Leave blank for none: " IMAGEPATH
			case $IMAGEPATH in
				"") echo "No answer given. Skipping.";
				break;;
				*)
				echo "$IMAGEPATH"
				IMAGEPATH=$(readlink -f "$IMAGEPATH")
				if [ -d "$IMAGEPATH" ]; then
					echo "Using folder $IMAGEPATH."
					# Remove existing default pool
					sudo virsh pool-destroy default
					sudo virsh pool-undefine default
					echo "List all pools after deletion"
					sudo virsh pool-list --all
					# Create new default pool
					sudo virsh pool-define-as default dir - - - - "$IMAGEPATH"
					sudo virsh pool-autostart default
					sudo virsh pool-start default
					echo "List all pools after re-creation"
					sudo virsh pool-list --all
					sudo virsh pool-info default
					break
				else
					echo "$IMAGEPATH is not detected to be a folder. Please input a folder or press enter to skip."
				fi;;
			esac
		done

		# Set config info
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

# TODO: Enable accept_ra https://superuser.com/questions/1208952/qemu-kvm-libvirt-forwarding
# TODO: echo "2" > /proc/sys/net/ipv6/conf/enp2s0/accept_ra
# TODO: https://wiki.gentoo.org/wiki/QEMU/KVM_IPv6_Support
# 		sudo bash -c "cat >/tmp/default.xml" <<'EOL'
# <network>
#   <name>default</name>
#   <forward mode='nat'/>
#   <bridge name='virbr0' stp='off'/>
#   <ip address='192.168.122.1' netmask='255.255.255.0'>
#     <dhcp>
#       <range start='192.168.122.2' end='192.168.122.254'/>
#     </dhcp>
#   </ip>
#   <ip family='ipv6' address='2001:db8:dead:beef:fe::2' prefix='96'>
#     <dhcp>
#       <range start='2001:db8:dead:beef:fe::1000' end='2001:db8:dead:beef:fe::2000' />
#     </dhcp>
#   </ip>
# </network>
# EOL
# 		sudo virsh net-destroy default
# 		cd /tmp
# 		sudo virsh net-define default.xml
# 		sudo virsh net-start default

		# Set dconf info
		gsettings set org.virt-manager.virt-manager.stats enable-cpu-poll true
		gsettings set org.virt-manager.virt-manager.stats enable-disk-poll true
		gsettings set org.virt-manager.virt-manager.stats enable-memory-poll true
		gsettings set org.virt-manager.virt-manager.stats enable-net-poll true
		gsettings set org.virt-manager.virt-manager.vmlist-fields cpu-usage true
		gsettings set org.virt-manager.virt-manager.vmlist-fields disk-usage false
		gsettings set org.virt-manager.virt-manager.vmlist-fields memory-usage true
		gsettings set org.virt-manager.virt-manager.vmlist-fields network-traffic true
		gsettings set org.virt-manager.virt-manager.console resize-guest 1

	break;;

	[2]* )
	echo "You asked to remove virt-manager."
	sudo virsh net-autostart default --disable
	sudo virsh net-destroy default
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
		sudo systemctl stop libvirtd
		sudo systemctl disable libvirtd
		sudo dnf remove -y qemu-kvm virt-install virt-viewer libvirt-daemon-config-network libvirt-daemon-kvm virt-manager
	fi
	sudo rm -f /etc/polkit-1/rules.d/80-libvirt.rules
	break;;

	* ) echo "Please input 0, 1 or 2.";;
    esac
done
