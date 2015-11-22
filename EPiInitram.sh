#!/bin/bash

set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Stash locations
STASHINITRD="/media/Box/RPi/initram_custom.img"

# Chroot command
#CHROOTCMD="systemd-nspawn -D ${INSTALLPATH}"

# Kernel version
KERNELVERSION="$(uname -r)"

if [ ! -d "/lib/modules/${KERNELVERSION}" ]; then
	echo "No modules folder found. Exiting."
	exit 1;
fi

if [ ! -d /media/Box/RPi ]; then
	echo "Error, no Box RPi folder. Exiting."
	exit 1;
fi

if [[ ! $(type -P mkinitramfs) ]]; then
	#echo "No mkinitramfs found. Exiting."
	echo "Installing mkinitramfs tools."
	apt-get install -y initramfs-tools nbd-client
	#echo "Install using apt-get install initramfs-tools"
	#exit 1;
fi

if [ -f $STASHINITRD ]; then
	echo "Deleting existing initram file $STASHINITRD."
	rm "$STASHINITRD"
fi

echo "Creating initram at ${STASHINITRD}."
mkinitramfs -o "${STASHINITRD}" "${KERNELVERSION}"
chmod a+rwx "${STASHINITRD}"

if mount | grep "/boot type vfat"; then
	echo "Copying initram to boot partition."
	cp -f "${STASHINITRD}" /boot/
fi

echo "Script completed successfully."
