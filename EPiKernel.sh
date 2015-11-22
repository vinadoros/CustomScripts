#!/bin/bash

set -eu

# Build RPi kernel from https://github.com/raspberrypi/linux
echo "Executing EPiKernel.sh"

RPIKERNELURL="https://github.com/raspberrypi/linux/archive/rpi-4.1.y.zip"
ZIPIMG="$(basename ${RPIKERNELURL})"
ZIPFOLDER="linux-${ZIPIMG%.zip}"

# Compiler Variables
export CCPREFIX=arm-none-eabi-
CCBIN="${CCPREFIX}gcc"
export CROSS_COMPILE=${CCPREFIX}
export ARCH=arm

# CPU Cores available
CPUCORES=$(grep -c ^processor /proc/cpuinfo)

# Stash locations
STASHMODULES="/media/Box/RPi/modules.tar.gz"
STASHKERNEL="/media/Box/RPi/kernel_custom.img"

if [[ ! $(type -P $CCBIN) ]]; then
	echo "Installing compiler binaries."
	[ $(type -p pacman) ] && sudo pacman -S --needed --noconfirm arm-none-eabi-gcc
fi

if [[ ! $(type -P $CCBIN) ]]; then
	echo "No compiler binaries found. Exiting."
	exit 1;
fi

if [ ! -d /media/Box/RPi ]; then
	echo "Error, no Box RPi folder. Exiting."
	exit 1;
fi

if [ ! -f "${ZIPIMG}" ]; then
	wget "$RPIKERNELURL"
fi
if [ ! -d "${ZIPFOLDER}" ]; then
	7z x "${ZIPIMG}"
fi
cd "${ZIPFOLDER}"

# Make kernel
make mrproper
make bcm2709_defconfig
#make menuconfig

sed -i 's/CONFIG_BLK_DEV_NBD=m/CONFIG_BLK_DEV_NBD=y/g' ./.config
sed -i 's/CONFIG_BTRFS_FS=m/CONFIG_BTRFS_FS=y/g' ./.config
sed -i 's/CONFIG_XOR_BLOCKS=m/CONFIG_XOR_BLOCKS=y/g' ./.config
sed -i 's/CONFIG_RAID6_PQ=m/CONFIG_RAID6_PQ=y/g' ./.config
sed -i 's/CONFIG_ZLIB_DEFLATE=m/CONFIG_ZLIB_DEFLATE=y/g' ./.config
sed -i 's/CONFIG_LOCALVERSION=.*$/CONFIG_LOCALVERSION="-RMKCUSTOM"/g' ./.config

#read -p "Wait."

make zImage modules dtbs -j ${CPUCORES}

if [ -f /media/Box/RPi/kernel_custom.img ]; then
	echo "Deleting existing kernel "$STASHKERNEL"."
	rm "$STASHKERNEL"
fi
echo "Stashing kernel to ${STASHKERNEL}."
scripts/mkknlimg arch/arm/boot/zImage ${STASHKERNEL}

if [ -d ../modules ]; then
	rm -rf ../modules
fi
mkdir ../modules

echo "Copying Modules."
make INSTALL_MOD_PATH=../modules modules_install
chmod a+rwx -R ../modules
#chown 0:0 -R ../modules

if [ -f "$STASHMODULES" ]; then
	echo "Deleting existing modules file $STASHMODULES."
	rm "$STASHMODULES"
fi

echo "Stashing modules to $STASHMODULES."
tar -czpvf "$STASHMODULES" -C ../modules/lib .
rm -rf ../modules

echo "Script completed successfully."
