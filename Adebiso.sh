#!/bin/bash

# https://debian-live.alioth.debian.org/live-manual/stable/manual/html/live-manual.en.html

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
fi
USERGROUP=$(id $USERNAMEVAR -gn)
USERHOME=/home/$USERNAMEVAR

# Install required utilities
if ! type lb; then
  sudo apt-get update
  sudo apt-get install -y live-build
fi

# Enable error handling
set -e

WORKINGFOLDER="$USERHOME/buildfolder"
# Create folder if it doesn't exist
if [ ! -d $WORKINGFOLDER ]; then
  mkdir -p $WORKINGFOLDER
fi

if [ -d $WORKINGFOLDER ]; then
  cd $WORKINGFOLDER
  # Clean folder if it exists
  sudo lb clean
  # Configure live build
  lb config
	# Add packages
	cat > config/package-lists/custom.list.chroot<<'EOL'
# Desktop utils
task-mate-desktop
firefox
# Recovery and Backup utils
clonezilla
gparted
EOL
	# Add repositories
	echo "deb http://ftp.us.debian.org/debian unstable main contrib non-free" | tee config/archives/your-repository.list.binary | tee config/archives/your-repository.list.chroot
	# Modify bootloader settings
	mkdir -p binary/isolinux
	cat > binary/isolinux/isolinux.cfg <<'EOL'
include menu.cfg
default vesamenu.c32
prompt 0
timeout 10
EOL
	# Build the image
	#sudo lb build
fi
