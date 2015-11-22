#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Distribution to use for virtualbox debian repo.
DEBRELEASE=$(lsb_release -si)
if [[ "$DEBRELEASE" = "Debian" ]]; then
	VBOXDEBRELEASE=squeeze
elif [[ "$DEBRELEASE" = "Ubuntu" ]]; then
	VBOXDEBRELEASE=vivid
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

# Install virtualbox host
if [[ $VBOXGUEST = 0 && $QEMUGUEST = 0 && $VMWGUEST = 0 ]] && ! dpkg-query -l | grep -iq "virtualbox"; then
	wget -q http://download.virtualbox.org/virtualbox/debian/oracle_vbox.asc -O- | sudo apt-key add -
	if ! grep -iq "download.virtualbox.org" "/etc/apt/sources.list"; then
	    add-apt-repository "deb http://download.virtualbox.org/virtualbox/debian ${VBOXDEBRELEASE} contrib non-free"
	fi
	apt-get update
	apt-get install -y virtualbox-5.0
	VBOXVER=$(vboxmanage -v)
	VBOXVER2=$(echo $VBOXVER | cut -d 'r' -f 1)
	wget -P ~/ http://download.virtualbox.org/virtualbox/$VBOXVER2/Oracle_VM_VirtualBox_Extension_Pack-$VBOXVER2.vbox-extpack
	VBoxManage extpack install ~/Oracle_VM_VirtualBox_Extension_Pack-$VBOXVER2.vbox-extpack
	rm ~/Oracle_VM_VirtualBox_Extension_Pack-$VBOXVER2.vbox-extpack
fi
