#!/bin/bash

if [[ ! $(type -P mkisofs) ]]; then
	if [[ $(type -P pacman) ]]; then
		sudo pacman -S --needed --noconfirm cdrkit
	fi
fi

BOXFOLDER=/media/Box/LinuxScripts

if [ ! -d $BOXFOLDER ]; then
	echo "No Box folder found. Exiting"
	exit 1;
fi

if [ ! -f /usr/bin/mkisofs ]; then
	echo "No mkisofs command found. Exiting"
	exit 1;
fi

if [ -f ~/box.iso ]; then
	rm ~/box.iso
fi

mkisofs -J -R -o ~/box.iso /media/Box/LinuxScripts/
echo "Image created successfully."
