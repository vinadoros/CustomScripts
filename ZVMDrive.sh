#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

DRIVE=$1
if [ -z $DRIVE ]; then
	DRIVE=/dev/sda
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
#DRIVEMBSIZE=$(( $DRIVESIZE / 1048576 ))
DRIVEMBSIZE=$(( $DRIVESIZE / 1000000 ))
SWAPSIZE=1024
MAINDRIVE=$(( $DRIVEMBSIZE - $SWAPSIZE ))

echo "Drive: ${DRIVE}"
echo "Drive Size (bytes): ${DRIVESIZE}"
echo "Drive Size (MB): ${DRIVEMBSIZE}"
echo "Swap Size: ${SWAPSIZE}"
echo "Main Partition Size: ${MAINDRIVE}"
read -p "Press any key to continue."

# Remove each partition
for v_partition in $(parted -s "$DRIVE" print|awk '/^ / {print $1}')
do
   parted -s -a minimal "$DRIVE" rm ${v_partition}
done

dd if=/dev/zero of="$DRIVE" bs=1M count=4 conv=notrunc
parted -s -a optimal "$DRIVE" -- mktable msdos
parted -s -a optimal "$DRIVE" -- mkpart primary ext2 1 $MAINDRIVE
parted -s -a optimal "$DRIVE" -- mkpart primary linux-swap $(( $MAINDRIVE )) 100%
mkfs.ext4 "${DRIVE}1"
mkswap "${DRIVE}2"
mount "${DRIVE}1" /mnt
swapon "${DRIVE}2"
sync
