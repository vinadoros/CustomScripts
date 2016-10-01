#!/bin/bash

###############################################################################
##################        Initial Setup and Variables      ####################
###############################################################################
# Halt on any error.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

###############################################################################
#########################        Compose Script      ##########################
###############################################################################

source "$SCRIPTDIR/Comp-InitVars.sh"

# Install a desktop environment. 0=do nothing, 1=KDE, 2=cinnamon, 3=GNOME, 4=xfce, 5=MATE
read -p "Enter a number to install a desktop environment (0=do nothing/default option, 1=KDE, 2=cinnamon, 3=GNOME, 4=xfce, 5=MATE):" SETDE
SETDE=${SETDE//[^a-zA-Z0-9_]/}
if [ -z "$SETDE" ]; then
	echo "No input found. Defaulting to 0."
	SETDE=0
fi
echo "You entered $SETDE"

# Change/Setup display manager. 0=do nothing, 1=SDDM, 2=LightDM gtk, 3=GDM, 4=LightDM kde
read -p "Enter a number to install a display manager (0=do nothing/default option, 1=SDDM, 2=LightDM gtk, 3=GDM, 4=LightDM kde):" SETDM
SETDM=${SETDM//[^a-zA-Z0-9_]/}
if [ -z "$SETDM" ]; then
	echo "No input found. Defaulting to 0."
	SETDM=0
fi
echo "You entered $SETDM"

read -p "Press any key to continue."

# Set up some folders.
if [[ ! -d $USERHOME/.config/autostart/ ]]; then
	mkdir -p $USERHOME/.config/autostart/
	chown -R $USERNAMEVAR:$USERGROUP $USERHOME/.config
fi

source "$SCRIPTDIR/Comp-ArchAUR.sh"

source "$SCRIPTDIR/Comp-ArchSoftware.sh"

source "$SCRIPTDIR/Comp-sdtimers.sh"

source "$SCRIPTDIR/Comp-ArchCron.sh"

source "$SCRIPTDIR/Comp-sshconfig.sh"

source "$SCRIPTDIR/Comp-Fish.sh"

source "$SCRIPTDIR/Comp-Bash.sh"

source "$SCRIPTDIR/Comp-CSClone.sh"

source "$SCRIPTDIR/Comp-DisplayManagerConfig.sh"

source "$SCRIPTDIR/Comp-SambaConfig.sh"

source "$SCRIPTDIR/Comp-xdgdirs.sh"

source "$SCRIPTDIR/Comp-zram.sh"

source "$SCRIPTDIR/Comp-RPiGeneral.sh"

source "$SCRIPTDIR/Comp-SysConfig.sh"

sleep 1
echo ""
echo "Script Completed Successfully."
echo ""
