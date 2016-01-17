#!/bin/bash

set -e

if type -p pacman &> /dev/null; then
	echo "Not installing packages."
elif type -p apt-get &> /dev/null; then
	sudo apt-get install -y git build-essential zip gnome-common libglib2.0-dev
elif type -p dnf &> /dev/null; then
	sudo dnf install -y gnome-common intltool glib2-devel
fi

TEMPFOLDER=./tempfolder
[ -d "$TEMPFOLDER" ] && rm -rf "$TEMPFOLDER"

# Dash to dock
git clone https://github.com/micheleg/dash-to-dock.git "$TEMPFOLDER"
cd "$TEMPFOLDER"
make
make install
cd ..
rm -rf "$TEMPFOLDER"

# Top icons
#~ git clone http://94.247.144.115/~git/topicons.git "$TEMPFOLDER"
#~ cd "$TEMPFOLDER"
#~ sudo install -Dm644 "metadata.json" "/usr/share/gnome-shell/extensions/topIcons@adel.gadllah@gmail.com/metadata.json"
#~ sudo install -m644 "extension.js" "/usr/share/gnome-shell/extensions/topIcons@adel.gadllah@gmail.com/extension.js"
#~ cd ..
#~ rm -rf "$TEMPFOLDER"
mkdir "$TEMPFOLDER"
cd "$TEMPFOLDER"
wget -O topicons.zip "https://extensions.gnome.org/download-extension/topIcons@adel.gadllah@gmail.com.shell-extension.zip?version_tag=5335"
7z e ./topicons.zip
sudo install -Dm644 "metadata.json" "/usr/share/gnome-shell/extensions/topIcons@adel.gadllah@gmail.com/metadata.json"
sudo install -m644 "extension.js" "/usr/share/gnome-shell/extensions/topIcons@adel.gadllah@gmail.com/extension.js"
cd ..
rm -rf "$TEMPFOLDER"

# MediaPlayer
git clone https://github.com/eonpatapon/gnome-shell-extensions-mediaplayer.git "$TEMPFOLDER"
cd "$TEMPFOLDER"
./autogen.sh
make
sudo make install
cd ..
rm -rf "$TEMPFOLDER"

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
