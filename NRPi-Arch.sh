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

source "$SCRIPTDIR/Comp-NScriptSetup.sh"

source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

###############################################################################
#########################        Compose Script      ##########################
###############################################################################

bash -c "cat >>${SETUPSCRIPT}" <<'EOLXYZ'
#!/bin/bash
# Halt on any error.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

EOLXYZ

nscriptadd "$SCRIPTDIR/Comp-GeneralFunctions.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-InitVars.sh" "${SETUPSCRIPT}"

bash -c "cat >>${SETUPSCRIPT}" <<'EOLXYZ'

# Install a desktop environment. 0=do nothing, 1=KDE, 2=cinnamon, 3=GNOME, 4=xfce, 5=MATE
read -p "Enter a number to install a desktop environment (0=do nothing/default option, 1=KDE, 2=cinnamon, 3=GNOME, 4=xfce, 5=MATE):" SETDE
SETDE=${SETDE//[^a-zA-Z0-9_]/}
if [ -z "$SETDE" ]; then
	echo "No input found. Defaulting to 0."
	SETDE=0
fi
echo "You entered" $SETDE

# Change/Setup display manager. 0=do nothing, 1=SDDM, 2=LightDM gtk, 3=GDM, 4=LightDM kde
read -p "Enter a number to install a display manager (0=do nothing/default option, 1=SDDM, 2=LightDM gtk, 3=GDM, 4=LightDM kde):" SETDM
SETDM=${SETDM//[^a-zA-Z0-9_]/}
if [ -z "$SETDM" ]; then
	echo "No input found. Defaulting to 0."
	SETDM=0
fi
echo "You entered" $SETDM

read -p "Press any key to continue."

# Set up some folders.
if [[ ! -d $USERHOME/.config/autostart/ ]]; then
	mkdir -p $USERHOME/.config/autostart/
	chown -R $USERNAMEVAR:$USERGROUP $USERHOME/.config
fi

# Set lightdm autologin flag to true.
export LIGHTDMAUTO=1

EOLXYZ

nscriptadd "$SCRIPTDIR/Comp-ArchAUR.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-ArchSoftware.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-sdtimers.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-ArchCron.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-ArchInfinality.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-sshconfig.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-Fish.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-Bash.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-CSClone.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-BoxDAV.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-LightDMAutoLogin.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-SambaConfig.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-xdgdirs.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-zram.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-RPiGeneral.sh" "${SETUPSCRIPT}"

nscriptadd "$SCRIPTDIR/Comp-SysConfig.sh" "${SETUPSCRIPT}"

bash -c "cat >>${SETUPSCRIPT}" <<'EOLXYZ'

echo -e "\n****************************************\n*****Script Completed Successfully!*****\n****************************************\n"
EOLXYZ

chmod a+rwx "${SETUPSCRIPT}"
echo "Script generated at ${SETUPSCRIPT}."
