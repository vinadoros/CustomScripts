#!/bin/bash

###############################################################################
##################        Initial Setup and Variables      ####################
###############################################################################
set +eu

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

DEBRELEASE=$(lsb_release -sc)

source "$SCRIPTDIR/Comp-InitVars.sh"

# Install a desktop environment. 0=do nothing, 1=KDE, 2=GNOME, 3=MATE
if [ -z "$SETDE" ]; then
	read -p "Enter a number to install a desktop environment (0=do nothing/default option, 1=KDE, 2=GNOME, 3=MATE):" SETDE
	export SETDE=${SETDE//[^a-zA-Z0-9_]/}
	if [ -z "$SETDE" ]; then
		echo "No input found. Defaulting to 0."
		export SETDE=0
	fi
fi
echo "You entered $SETDE"

read -p "Press any key to continue."
set -eu

source "$SCRIPTDIR/Comp-DebianRepos.sh"

source "$SCRIPTDIR/Comp-DebianSoftware.sh"

source "$SCRIPTDIR/Comp-sdtimers.sh"

source "$SCRIPTDIR/Comp-sshconfig.sh"

source "$SCRIPTDIR/Comp-Fish.sh"

source "$SCRIPTDIR/Comp-Bash.sh"

source "$SCRIPTDIR/Comp-CSClone.sh"

source "$SCRIPTDIR/Comp-BoxDAV.sh"

source "$SCRIPTDIR/Comp-DisplayManagerConfig.sh"

source "$SCRIPTDIR/Comp-SambaConfig.sh"

#source "$SCRIPTDIR/Comp-DebVBoxHost.sh"

source "$SCRIPTDIR/Comp-DebVMGuest.sh"

source "$SCRIPTDIR/Comp-VMGeneral.sh"

source "$SCRIPTDIR/Comp-xdgdirs.sh"

source "$SCRIPTDIR/Comp-zram.sh"

source "$SCRIPTDIR/Comp-SysConfig.sh"

sleep 1
echo ""
echo "Script Completed Successfully."
echo ""
