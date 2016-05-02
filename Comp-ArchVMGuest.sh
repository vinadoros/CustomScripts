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

[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

###############################################################################
##########################        Guest Section      ##########################
###############################################################################
# Install virtualbox guest utils
if [ $VBOXGUEST = 1 ]; then
	dist_install virtualbox-guest-modules-arch
	dist_install virtualbox-guest-utils
	modprobe -a vboxguest vboxsf vboxvideo

	# Add the user to the vboxsf group, so that the shared folders can be accessed.
	gpasswd -a $SUDO_USER vboxsf

	systemctl enable vboxservice
	systemctl start vboxservice
fi

# Install qemu/kvm guest utils.
if [ $QEMUGUEST = 1 ]; then
	dist_install spice-vdagent
	dist_install xf86-video-qxl
	systemctl enable spice-vdagentd
fi

# Install VMWare guest utils
if [ $VMWGUEST = 1 ]; then
	dist_install open-vm-tools
	dist_install xf86-input-vmmouse xf86-video-vmware mesa
	systemctl enable vmtoolsd.service
	systemctl enable vmware-vmblock-fuse.service
	if [ ! -f /etc/modules-load.d/vmware-guest.conf ]; then
		cat >>/etc/modules-load.d/vmware-guest.conf <<EOL
vmw_balloon
vmw_pvscsi
vmw_vmci
vmwgfx
vmxnet3
EOL
	fi
fi
