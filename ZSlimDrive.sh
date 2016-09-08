#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

BTRFSOPT=0
SWAP=0
NOPROMPT=0
FOLDERMOUNT=/mnt
BTRFSSUBVOLNAME=root

if [ ! -d "$FOLDERMOUNT" ]; then
	mkdir -p /mnt
fi

# Get options
while getopts ":sbd:n" OPT
do
	case $OPT in
		b)
			BTRFSOPT=1
			;;
		s)
			SWAP=1
			;;
		d)
			DRIVE="$OPTARG"
			;;
		n)
			NOPROMPT=1
			;;
		\?)
			echo "Invalid option: -$OPTARG" 1>&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument" 1>&2
			exit 1
			;;
	esac
done

if [[ -z $BTRFSOPT || $BTRFSOPT -ne 1 ]]; then
	BTRFSOPT=0
fi

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
SWAPSIZE=1024
MAINDRIVE=$(( $DRIVEMBSIZE - $SWAPSIZE ))

echo "Drive: ${DRIVE}"
echo "Drive Size (bytes): ${DRIVESIZE}"
echo "Drive Size (MB): ${DRIVEMBSIZE}"
if [[ $SWAP = 1 ]]; then
	echo "Swap Size: ${SWAPSIZE}"
	echo "Main Partition Size: ${MAINDRIVE}"
fi
if [[ $NOPROMPT != 1 ]]; then
	read -p "Press any key to continue."
fi

# Remove each partition
for v_partition in $(parted -s "$DRIVE" print|awk '/^ / {print $1}')
do
   parted -s -a minimal "$DRIVE" rm ${v_partition}
done

dd if=/dev/zero of="$DRIVE" bs=1M count=4 conv=notrunc
parted -s -a optimal "$DRIVE" -- mktable msdos
if [[ $SWAP = 0 ]]; then
	parted -s -a optimal "$DRIVE" -- mkpart primary ext2 1 100%
else
	parted -s -a optimal "$DRIVE" -- mkpart primary ext2 1 $MAINDRIVE
	parted -s -a optimal "$DRIVE" -- mkpart primary linux-swap $(( $MAINDRIVE )) 100%
fi

if [[ $SWAP = 1 ]]; then
	mkswap "${DRIVE}2"
	swapon "${DRIVE}2"
fi

if [[ $BTRFSOPT -eq 1 ]]; then
	mkfs.btrfs "${DRIVE}1"
	mount "${DRIVE}1" "${FOLDERMOUNT}"
	cd "${FOLDERMOUNT}"
	btrfs subvol create ${BTRFSSUBVOLNAME}
	cd /
	umount "${FOLDERMOUNT}"
	mount "${DRIVE}1" "${FOLDERMOUNT}" -o subvol=/${BTRFSSUBVOLNAME}
else
	mkfs.ext4 "${DRIVE}1"
	mount "${DRIVE}1" "${FOLDERMOUNT}"
fi

sync

echo "Script Completed Successfully."
