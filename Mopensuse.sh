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

# Ensure path has some essentials
PATH=$PATH:/usr/local/bin:/sbin:/usr/sbin

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

$SCRIPTDIR/Comp-OpensuseSoftware.py -d $SETDE

source "$SCRIPTDIR/Comp-sdtimers.sh"

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
