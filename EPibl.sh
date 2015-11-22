#!/bin/bash

# Build Bootloader
echo "Executing EPibl.sh"

if [ -z $BL ]; then
	read -p "Input a bootloader (1: u-boot, 2: barebox): " BL
	BL=${BL//[^a-zA-Z0-9_]/}
	if [[ "$BL" -lt 1 || "$BL" -gt 2 ]]; then
		BL=1
		echo "No input found. Defaulting to $BL."
	fi
	echo "You entered $BL"
fi

set -eu

# Fucntions

ubootvars () {
	BLURL="git://git.denx.de/u-boot.git"
	GITFOLDER="$(readlink -f ./u-boot)"
	BUILDIMG="u-boot.bin"
}

bareboxvars () {
	BLURL="git://git.pengutronix.de/git/barebox.git"
	GITFOLDER="$(readlink -f ./barebox)"
	BUILDIMG="barebox.bin"
}

compilervars () {
	
	# Compiler Variables
	export CCPREFIX=arm-none-eabi-
	CCBIN="${CCPREFIX}gcc"
	export CROSS_COMPILE=${CCPREFIX}
	export ARCH=arm

	# CPU Cores available
	CPUCORES=$(nproc)
	
	if [[ ! $(type -P $CCBIN) ]]; then
		echo "Installing compiler binaries."
		[ $(type -p pacman) ] && sudo pacman -S --needed --noconfirm arm-none-eabi-gcc
	fi

	if [[ ! $(type -P $CCBIN) ]]; then
		echo "No compiler binaries found. Exiting."
		exit 1;
	fi
	
}

stashvars () {
	# Stash locations
	STASHIMG="/media/Box/RPi/${BUILDIMG}"
	
	if [ ! -d /media/Box/RPi ]; then
		echo "Error, no Box RPi folder. Exiting."
		exit 1;
	fi
}

stashbuild () {
	if [ -f "$STASHIMG" ]; then
		echo "Removing existing $STASHIMG."
		rm "$STASHIMG"
	fi
	echo "Storing to $STASHIMG."
	cp "${GITFOLDER}/${BUILDIMG}" "$STASHIMG"
}

ubootbuild () {
	make distclean
	make rpi_2_config
	#~ make xconfig
	make u-boot.bin -j ${CPUCORES}
}

bareboxbuild () {
	make distclean
	make rpi_defconfig
	#~ make xconfig
	make -j ${CPUCORES}
}

clonegitfolder () {
	if [ ! -d "${GITFOLDER}" ]; then
		git clone "${BLURL}"
	fi
	cd "${GITFOLDER}"
}

cleangitfolder () {
	if [ -d GITFOLDER ]; then
		echo "Removing $GITFOLDER."
		#~ rm -rf "$GITFOLDER"
	fi
}

if [ $BL = 2 ]; then
	bareboxvars
elif [ $BL = 1 ]; then
	ubootvars
fi

echo "Git url: $BLURL"
echo "Local build folder: $GITFOLDER"

read -p "Press any key to continue." 

stashvars

compilervars

clonegitfolder

if [ $BL = 2 ]; then
	bareboxbuild
elif [ $BL = 1 ]; then
	ubootbuild
fi

stashbuild
cleangitfolder

echo "Script completed successfully."
