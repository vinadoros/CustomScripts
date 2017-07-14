#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
	USERGROUP=$(id 1000 -gn)
	USERHOME="$(eval echo ~$USERNAMEVAR)"
fi

# Enable error halting.
set -eu

# Create xdg folders
if [ "$(id -u)" == "0" ]; then
	su $USERNAMEVAR -s /bin/bash <<'EOL'
xdg-user-dirs-update
EOL
else
	xdg-user-dirs-update
fi

# xdg dirs configuration
if [ -f $USERHOME/.config/user-dirs.dirs ]; then
	chmod 777 $USERHOME/.config/user-dirs.dirs
	sed -i 's/XDG_DOWNLOAD_DIR=.*$/XDG_DOWNLOAD_DIR=\"$HOME\/\"/g' $USERHOME/.config/user-dirs.dirs
	if [ -d $USERHOME/Downloads ]; then rm -r $USERHOME/Downloads; fi;
	sed -i 's/XDG_TEMPLATES_DIR=.*$/XDG_TEMPLATES_DIR=\"$HOME\/\"/g' $USERHOME/.config/user-dirs.dirs
	if [ -d $USERHOME/Templates ]; then rm -r $USERHOME/Templates; fi;
	sed -i 's/XDG_PUBLICSHARE_DIR=.*$/XDG_PUBLICSHARE_DIR=\"$HOME\/\"/g' $USERHOME/.config/user-dirs.dirs
	if [ -d $USERHOME/Public ]; then rm -r $USERHOME/Public; fi;
	sed -i 's/XDG_DOCUMENTS_DIR=.*$/XDG_DOCUMENTS_DIR=\"$HOME\/\"/g' $USERHOME/.config/user-dirs.dirs
	if [ -d $USERHOME/Documents ]; then rm -r $USERHOME/Documents; fi;
	sed -i 's/XDG_PICTURES_DIR=.*$/XDG_PICTURES_DIR=\"$HOME\/\"/g' $USERHOME/.config/user-dirs.dirs
	if [ -d $USERHOME/Pictures ]; then rm -r $USERHOME/Pictures; fi;
	sed -i 's/XDG_MUSIC_DIR=.*$/XDG_MUSIC_DIR=\"$HOME\/\"/g' $USERHOME/.config/user-dirs.dirs
	if [ -d $USERHOME/Music ]; then rm -r $USERHOME/Music; fi;
	sed -i 's/XDG_VIDEOS_DIR=.*$/XDG_VIDEOS_DIR=\"$HOME\/\"/g' $USERHOME/.config/user-dirs.dirs
	if [ -d $USERHOME/Videos ]; then rm -r $USERHOME/Videos; fi;
fi

if [ ! -d $USERHOME/.local/share/applications/ ]; then
	mkdir -p $USERHOME/.local/share/applications/
	chown -R ${USERNAMEVAR}:${USERGROUP} $USERHOME/.local
fi
