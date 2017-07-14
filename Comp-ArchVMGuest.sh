#!/bin/bash

# Disable error handlingss
set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

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
	USERHOME="$(eval echo ~$USERNAMEVAR)"
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
	# Add the user to the vboxsf group, so that the shared folders can be accessed.
	gpasswd -a $USERNAMEVAR vboxsf
	systemctl enable vboxservice
fi

# Install qemu/kvm guest utils.
if [ $QEMUGUEST = 1 ]; then
	dist_install spice-vdagent
	systemctl enable spice-vdagentd
	dist_install qemu-guest-agent
	systemctl enable qemu-ga
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
