#!/bin/bash
set -e
#
# bootify: make bootable USB drives with Windows 7/8 installation files
#
# Copyright (C) 2015 oneohthree
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Global variable declarations
VER="2.0"
ISOFOLDER="/mnt/isomount-35b166"
WORKINGFOLDER="/mnt/usbworkingfolder-35b166"
WORKINGBOOTFOLDER="/mnt/usbbootfolder-35b166"
# Remove trailing numbers from device to be used
DEV="${DEV%[0-9]}"

function usage()
{
cat <<EOF
Usage: $0 -d [DEVICE] -i [ISO]

Options:

-d [DEVICE]     USB device name, eg /dev/sdb
-i [ISO FILE]   path to the ISO file
-h              display this help and exit
-l              display available USB devices and exit
-v              display version and exit
EOF
}

function version()
{
	echo "bootify $VER"
}

function available_devices
{
	lsblk -ndo tran,name,vendor,model,size | grep usb | tr -s " "  " "
}

function get_iso_label()
{
	ISOLABEL=$(file -br "$ISO" |  awk -F\' '{print $2}')
}

function remove_working_folders()
{
	# sync
	# sleep 1

	#If iso and working folders are found, remove them.
	#Check if working folders are mounted. Unmount them if so.
	if [ -d "${ISOFOLDER}" ]; then
		echo "Removing ${ISOFOLDER}"
		mount | grep -q "${ISOFOLDER}" && ( umount "${ISOFOLDER}" || umount -l "${ISOFOLDER}" )
		# Check if files exist in the folder. If there are none, delete the folder.
		if [[ -z $(ls "${ISOFOLDER}") ]]; then
			echo "Removing $ISOFOLDER"
			rm -r "${ISOFOLDER}"
		else
			echo "$ISOFOLDER is not empty. Not removing."
			ls -la "$ISOFOLDER"
		fi
	fi
	if [ -d "${WORKINGFOLDER}" ]; then
		echo "Removing ${WORKINGFOLDER}"
		mount | grep -q "${WORKINGFOLDER}" && ( umount "${WORKINGFOLDER}" || umount -l "${WORKINGFOLDER}" )
		# Check if files exist in the folder. If there are none, delete the folder.
		if [[ -z $(ls "${WORKINGFOLDER}") ]]; then
			echo "Removing $WORKINGFOLDER"
			rm -r "${WORKINGFOLDER}"
		else
			echo "$WORKINGFOLDER is not empty. Not removing."
			ls -la "$WORKINGFOLDER"
		fi
	fi
}


function create_working_folders()
{
	# Check if folders exist. If they do, remove them.
	[[ -d "${ISOFOLDER}" || -d "${WORKINGFOLDER}" ]] && remove_working_folders

	mkdir -p "${ISOFOLDER}"
	mkdir -p "${WORKINGFOLDER}"
	#~ mkdir -p "${WORKINGBOOTFOLDER}"
}


function mbr_part()
{
	# Use dd to remove partition table and delete filesystem info.
	dd if=/dev/zero of="$DEV" bs=1M count=4 conv=notrunc 2>/dev/null

	DRIVESIZE=$(blockdev --getsize64 "$DEV")
	DRIVEMBSIZE=$(( $DRIVESIZE / 1000000 ))
	EFISIZE=50
	MAINDRIVE=$(( $DRIVEMBSIZE - $EFISIZE ))

	parted -s -a optimal "$DEV" -- mktable msdos
	parted -s -a optimal "$DEV" -- mkpart primary ntfs 1 $MAINDRIVE set 1 boot
	parted -s -a optimal "$DEV" -- mkpart primary fat32 $MAINDRIVE 100% set 2 esp
	# Wait until partitions appear
	while [ ! -b ${DEV}1 ]; do sleep .5; done
	mkfs.ntfs -f -L "${ISOLABEL}" ${DEV}1
	mkfs.vfat -F32 -n "EFI" ${DEV}2
	copy_files
	install_grub_mbr
}

function install_grub_mbr()
{
	echo "Installing grub to ${DEV}"
	USBUUID=$(blkid -s UUID -o value "${DEV}1")
	grub-install --debug --target=i386-pc --boot-directory="${WORKINGFOLDER}/boot" "$DEV"
	cat >"${WORKINGFOLDER}/boot/grub/grub.cfg"<<EOF
default=0
timeout=3
color_normal=light-cyan/dark-gray
menu_color_normal=black/light-cyan
menu_color_highlight=white/black

menuentry "Start Windows Installation" {
    insmod ntfs
    insmod search_fs_uuid
    insmod chain
    search --no-floppy --fs-uuid ${USBUUID} --set root
    chainloader +1
    boot
}

menuentry "Boot from the first hard drive" {
    insmod ntfs
    insmod chain
    insmod part_gpt
    insmod part_msdos
    set root=(hd0)
    chainloader +1
    boot
}
EOF
}

function confirm()
{
	DSC=$(lsblk -ndo vendor,model,size $DEV | tr -s " " " ")
	read -p "$DSC is going to be formatted. Do you want to continue? (Y/N)" YN
	if [[ "$YN" == [Yy] ]]
	then
		true
	elif [[ "$YN" == [Nn] ]]
	then
		exit 0
	else
		echo "Please, use 'Y' or 'N'"
		confirm
	fi
}

function confirm_usb()
{
	read -p "***WARNING***: $DEV is not a USB device. Are you sure you want to continue? (Y/N)" YN
	if [[ "$YN" == [Yy] ]]
	then
		true
	elif [[ "$YN" == [Nn] ]]
	then
		echo "Exiting."
		exit 1
	else
		echo "Please, use 'Y' or 'N'"
		confirm_usb
	fi
}

function copy_files()
{
	mount ${DEV}1 "${WORKINGFOLDER}"
	mount -o ro "$ISO" "$ISOFOLDER"
	echo "Copying files."
	cp -rv "$ISOFOLDER"/* "${WORKINGFOLDER}"

	# Windows 7 missing UEFI boot file workaround
	# This does not happen with future Windows installation media

	if [[ ! -d ${WORKINGFOLDER}/efi/boot ]]
	then
		WIM="${ISOFOLDER}/sources/install.wim"
		EFI="1/Windows/Boot/EFI/bootmgfw.efi"
		DST="${WORKINGFOLDER}/efi/boot"
		7z e "$WIM" "$EFI" "-o${DST}" > /dev/null 2>&1 || { echo 1>&2 "Error extracting bootmgfw.efi"; exit 1; }
		mv "${DST}/bootmgfw.efi" "${DST}/bootx64.efi"
	fi

	wget https://raw.githubusercontent.com/pbatard/rufus/master/res/uefi/uefi-ntfs.img -O "${WORKINGFOLDER}/uefi-ntfs.img"
	dd if="${WORKINGFOLDER}/uefi-ntfs.img" of=${DEV}2 bs=512
	rm "${WORKINGFOLDER}/uefi-ntfs.img"

}

while getopts ":hlvd:i:" OPT
do
	case $OPT in
		h)
			usage
			exit 0
			;;
		v)
			version
			exit 0
			;;
		l)
			available_devices
			exit 0
			;;
		d)
			DEV="$OPTARG"
			;;
		i)
			ISO="$OPTARG"
			;;
		\?)
			echo "Invalid option: -$OPTARG" 1>&2
			usage
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument" 1>&2
			usage
			exit 1
			;;
	esac
done

# bootify needs all the parameters

if [[ -z "$DEV" ]] || [[ -z "$ISO" ]]
then
	usage
	exit 1
fi

# Check if dependencies are met


DEP="dd isoinfo lsblk mkfs.ntfs mkfs.vfat parted sha1sum stat 7z grub-install file blkid"
for D in $DEP
do
    if ! type $D > /dev/null 2>&1; then
		[ $(type -P pacman) ] && pacman -S --needed --noconfirm cdrkit
	fi
done
for D in $DEP
do
    type $D > /dev/null 2>&1 || { echo "$D is not ready" 1>&2; exit 1; }
done



# Make sure bootify runs as root

if [[ "$EUID" -ne 0 ]]
then
	echo "bootify must be run as root" 1>&2
	exit 1
fi

# Check if $DEV is a block device

if [[ ! -b "$DEV" ]]
then
	echo "$DEV is not a block device" 1>&2
	exit 1
fi

# Check if $DEV is a USB device

if [[ -z $(lsblk -ndo tran $DEV | grep usb) ]]
then
	confirm_usb
fi

# Check if $DEV is mounted. Unmount it if a working folder has mounted it.
[[ ! -z $(grep $DEV /proc/mounts) ]] && remove_working_folders
# If $DEV is still mounted, throw an error.
if [[ ! -z $(grep $DEV /proc/mounts) ]]
then
	echo "$DEV is mounted, dismount it and run bootify again" 1>&2
	exit 1
fi

# Check if $ISO exists and is valid

if [[ ! -f "$ISO" ]]
then
	echo "$ISO does not exist" 1>&2
	exit 1
elif [[ -z $(isoinfo -d -i "$ISO" | grep "CD-ROM is in ISO 9660 format") ]]
then
	echo "$ISO is not a valid ISO file" 1>&2
	exit 1
fi

# Check $DEV capacity

if [[ $(stat -c %s "$ISO") -gt $(lsblk -ndbo size $DEV) ]]
then
	echo "The device capacity is insufficient" 1>&2
	exit 1
fi

# Create working folders
create_working_folders
# Get iso label
get_iso_label

# Go to partitioning stage based on chosen boot method
confirm
mbr_part
remove_working_folders
echo "Your USB drive has been created successfully."
exit 0
