#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

BTRFSOPT=$1
if [[ -z $BTRFSOPT || $BTRFSOPT -ne 1 ]]; then
	BTRFSOPT=0
fi

DRIVE=$2
if [ -z $DRIVE ]; then
	[ -b /dev/sda ] && DRIVE=/dev/sda
	[ -b /dev/vda ] && DRIVE=/dev/vda
fi
if [ ! -b $DRIVE ]; then
	echo "Error, no drive $DRIVE found."
	exit 1
fi

sync
swapoff -a
# Unmount each partition
for v_partition in $(parted -s "$DRIVE" print|awk '/^ / {print $1}')
do
	echo "Unmounting ${DRIVE}${v_partition}"
	umount -l "${DRIVE}${v_partition}"
	umount -f "${DRIVE}${v_partition}"
done

DRIVESIZE=$(blockdev --getsize64 "$DRIVE")
DRIVEMBSIZE=$(( $DRIVESIZE / 1000000 ))

echo "Drive: ${DRIVE}"
echo "Drive Size (bytes): ${DRIVESIZE}"
echo "Drive Size (MB): ${DRIVEMBSIZE}"
read -p "Press any key to continue."

# Remove each partition
for v_partition in $(parted -s "$DRIVE" print|awk '/^ / {print $1}')
do
   parted -s -a minimal "$DRIVE" rm ${v_partition}
done

dd if=/dev/zero of="$DRIVE" bs=1M count=4 conv=notrunc
parted -s -a optimal "$DRIVE" -- mktable msdos
parted -s -a optimal "$DRIVE" -- mkpart primary ext2 1 100%

if [[ $BTRFSOPT -eq 1 ]]; then 
	mkfs.btrfs "${DRIVE}1"
else
	mkfs.ext4 "${DRIVE}1"
fi
mount "${DRIVE}1" /mnt

sync
