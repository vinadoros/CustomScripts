#!/bin/bash

set -e

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR="$SUDO_USER"
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR="$USER"
	else
		export USERNAMEVAR="$(id 1000 -un)"
	fi
	USERGROUP="$(id 1000 -gn)"
	USERHOME="/home/$USERNAMEVAR"
fi

if type -p pacman &> /dev/null; then
	echo "Not installing packages."
elif type -p zypper &> /dev/null; then
	sudo zypper install -y git gnome-common intltool glib2-devel zip unzip
elif type -p apt-get &> /dev/null; then
	sudo apt-get install -y git build-essential zip gnome-common libglib2.0-dev
elif type -p dnf &> /dev/null; then
	sudo dnf install -y gnome-common intltool glib2-devel zip unzip
fi

# Ensure we are in the user's home folder
cd $USERHOME

export TEMPFOLDER=./tempfolder
[ -d "$TEMPFOLDER" ] && rm -rf "$TEMPFOLDER"

function dashtodock {
	# Dash to dock
	pwd
	git clone https://github.com/micheleg/dash-to-dock.git "$TEMPFOLDER"
	cd "$TEMPFOLDER"
	make
	make install
	cd ..
	rm -rf "$TEMPFOLDER"
}

function mediaplayer {
	# MediaPlayer
	git clone https://github.com/eonpatapon/gnome-shell-extensions-mediaplayer.git "$TEMPFOLDER"
	cd "$TEMPFOLDER"
	./autogen.sh
	make
	sudo make install
	cd ..
	rm -rf "$TEMPFOLDER"
}

function volumemixer {
	# Volume Mixer
	git clone https://github.com/aleho/gnome-shell-volume-mixer.git "$TEMPFOLDER"
	cd "$TEMPFOLDER"
	make
	EXTDIR="$(readlink -f ~/.local/share/gnome-shell/extensions/shell-volume-mixer@derhofbauer.at/)"
	#EXTDIR="$(readlink -f /usr/share/gnome-shell/extensions/shell-volume-mixer@derhofbauer.at/)"
	mkdir -p "$EXTDIR"
	7z x ./shell-volume-mixer*.zip -aoa -o"$EXTDIR"
	cd ..
	rm -rf "$TEMPFOLDER"
}

function topiconsplus {
	# Top Icons Plus
	git clone https://github.com/phocean/TopIcons-plus "$TEMPFOLDER"
	cd "$TEMPFOLDER"
	make
	cd ..
	rm -rf "$TEMPFOLDER"
}

usage () {
	echo "h - help"
	echo "d - Dash to Dock"
	echo "m - Media Player"
	echo "v - Volume Mixer"
	echo "t - Top Icons Plus"
	exit 0;
}

# Get options
while getopts ":dmvth" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		d)
			export -f dashtodock
			[ "$(id -u)" = "0" ] && su $USERNAMEVAR -s /bin/bash -c dashtodock || dashtodock
			;;
		m)
			export -f mediaplayer
			[ "$(id -u)" = "0" ] && su $USERNAMEVAR -s /bin/bash -c mediaplayer || mediaplayer
			;;
		v)
			export -f volumemixer
			[ "$(id -u)" = "0" ] && su $USERNAMEVAR -s /bin/bash -c volumemixer || volumemixer
			;;
		t)
			export -f topiconsplus
			[ "$(id -u)" = "0" ] && su $USERNAMEVAR -s /bin/bash -c topiconsplus || topiconsplus
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
