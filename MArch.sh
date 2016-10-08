#!/bin/bash

###############################################################################
##################        Initial Setup and Variables      ####################
###############################################################################

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

NOPROMPT=0

usage () {
	echo "h - help"
	echo "e - Set Desktop Environment"
	echo "m - Set Display Manager"
	echo "s - Samba password"
	echo "n - Do not prompt to continue."
	exit 0;
}

# Get options
while getopts ":e:m:s:nh" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		e)
			SETDE="$OPTARG"
			;;
		m)
			SETDM="$OPTARG"
			;;
		s)
			SMBPASSWORD="$OPTARG"
			;;
		n)
			NOPROMPT=1
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

source "$SCRIPTDIR/Comp-InitVars.sh"

# Install a desktop environment. 0=do nothing, 1=KDE, 2=cinnamon, 3=GNOME, 4=xfce, 5=MATE
if [ -z "$SETDE" ]; then
	read -p "Enter a number to install a desktop environment (0=do nothing/default option, 1=KDE, 2=cinnamon, 3=GNOME, 4=xfce, 5=MATE):" SETDE
fi
SETDE=${SETDE//[^a-zA-Z0-9_]/}
if [ -z "$SETDE" ]; then
	echo "No input found. Defaulting to 0."
	SETDE=0
fi
echo "Desktop Environment is $SETDE"

# Change/Setup display manager. 0=do nothing, 1=SDDM, 2=LightDM gtk, 3=GDM, 4=LightDM kde
if [ -z "$SETDM" ]; then
	read -p "Enter a number to install a display manager (0=do nothing/default option, 1=SDDM, 2=LightDM gtk, 3=GDM, 4=LightDM kde):" SETDM
fi
SETDM=${SETDM//[^a-zA-Z0-9_]/}
if [ -z "$SETDM" ]; then
	echo "No input found. Defaulting to 0."
	SETDM=0
fi
echo "Display Manager is $SETDM"

if [[ $NOPROMPT != 1 ]]; then
	read -p "Press any key to continue."
fi
# Halt on any error.
set -eu

# Set up some folders.
if [[ ! -d $USERHOME/.config/autostart/ ]]; then
	mkdir -p $USERHOME/.config/autostart/
	chown -R $USERNAMEVAR:$USERGROUP $USERHOME/.config
fi

source "$SCRIPTDIR/Comp-ArchAUR.sh"

source "$SCRIPTDIR/Comp-ArchSoftware.sh"

source "$SCRIPTDIR/Comp-sdtimers.sh"

source "$SCRIPTDIR/Comp-ArchCron.sh"

source "$SCRIPTDIR/Comp-ArchInfinality.sh"

source "$SCRIPTDIR/Comp-ArchVMGuest.sh"

source "$SCRIPTDIR/Comp-VMGeneral.sh"

source "$SCRIPTDIR/Comp-sshconfig.sh"

"$SCRIPTDIR/Comp-BashFish.py"

source "$SCRIPTDIR/Comp-CSClone.sh"

source "$SCRIPTDIR/Comp-DisplayManagerConfig.sh"

source "$SCRIPTDIR/Comp-SambaConfig.sh"

source "$SCRIPTDIR/Comp-xdgdirs.sh"

source "$SCRIPTDIR/Comp-zram.sh"

source "$SCRIPTDIR/Comp-SysConfig.sh"

sleep 1
echo ""
echo "Script Completed Successfully."
echo ""
