#!/bin/bash

set +eu

echo "Executing EPifstab.sh."

if [ -z "$MACHINEARCH" ]; then
	MACHINEARCH=$(uname -m)
fi

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Get real link (extract symlink if it exists)
FSTABPATH=$(readlink -f "${1%/}")
FSTABFILE=$(readlink -f "$FSTABPATH/etc/fstab")
FSTABIMG=$(mount | grep -i "$FSTABPATH" | cut -f1 -d" ")

echo "fstab path: $FSTABPATH"
echo "fstab file: $FSTABFILE"
echo "Image (if applicable): $FSTABIMG"

# Fstab add blank function
fstabblank ()
{
	if [ ! -z "$(tail -1 /etc/fstab)" ]; then echo "" >> /etc/fstab ; fi
}

if [ -f "${FSTABFILE}" ] && ! grep -iq "box.com" "${FSTABFILE}"; then
	echo "Deleting ${FSTABFILE}."
	rm "${FSTABFILE}"
fi

if [ ! -f "${FSTABFILE}" ]; then
	echo "Creating ${FSTABFILE}."
	touch "${FSTABFILE}"
	chmod a+r "${FSTABFILE}"
fi

if [ "$MACHINEARCH" != "armv7l" ]; then
	if losetup | grep -iq "$FSTABIMG" && [ ! -z "$FSTABIMG" ]; then
		echo "Found $FSTABIMG."
		if ! grep -iq "nbd0" "${FSTABFILE}"; then
			fstabblank
			echo -e "/dev/nbd0\t/\tauto\tdefaults,rw\t0\t0" | tee -a "${FSTABFILE}"
		fi
		if ! grep -iq "mmcblk0p1" "${FSTABFILE}"; then
			echo -e "/dev/mmcblk0p1\t/boot\tvfat\tdefaults,umask=0,noauto\t0\t0" | tee -a "${FSTABFILE}"
		fi
	elif mount | grep -iq "$FSTABPATH" && [ ! -z "$FSTABIMG" ]; then
		echo "$FSTABPATH is a mount point."
		if ! grep -iq "mmcblk0p2" "${FSTABFILE}"; then
			fstabblank
			echo -e "/dev/mmcblk0p2\t/\tauto\tdefaults,rw\t0\t0" | tee -a "${FSTABFILE}"
		fi
		if ! grep -iq "mmcblk0p1" "${FSTABFILE}"; then
			echo -e "/dev/mmcblk0p1\t/boot\tvfat\tdefaults,umask=0\t0\t0" | tee -a "${FSTABFILE}"
		fi
	fi
fi

if [ "$MACHINEARCH" = "armv7l" ]; then
	# Add fstab line for boot and 2nd flash partition
	if ! grep -iq "mmcblk0p1" "${FSTABFILE}"; then
		echo "Adding mmcblk0p1 to ${FSTABFILE}"
		fstabblank
		echo -e "/dev/mmcblk0p1\t/boot\tvfat\tdefaults,umask=0,noauto\t0\t0" | tee -a "${FSTABFILE}"
	fi
	if ! grep -iq "$FSTABIMG" "${FSTABFILE}"; then
		echo "Adding $FSTABIMG to ${FSTABFILE}"
		fstabblank
		echo -e "${FSTABIMG}\t/\tauto\tdefaults\t0\t0" | tee -a "${FSTABFILE}"
	fi	
fi

fstabblank
