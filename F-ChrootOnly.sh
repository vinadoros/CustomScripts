#!/bin/bash

echo "Executing F-ChrootOnly.sh."

if [[ -z "${INSTALLPATH}" && ! -z "$1" ]]; then
	INSTALLPATH=$(readlink -f ${1%/})
fi
if [ -z "${INSTALLPATH}" ]; then
	echo "No install path found. Exiting."
	exit 1;
fi

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	echo "No username found. Exiting."
	exit 1;
fi
CHUSERHOME="$INSTALLPATH/home/$USERNAMEVAR"

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"

# Add general functions if they don't exist.
type -t grepadd || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"


grepadd 'export PATH=$PATH:/bin:/usr/local/sbin:/usr/sbin:/sbin' "$INSTALLPATH/root/.bashrc"
grepadd "export QT_X11_NO_MITSHM=1" "$INSTALLPATH/root/.bashrc"
grepadd 'export PATH=$PATH:/bin:/usr/local/sbin:/usr/sbin:/sbin' "$CHUSERHOME/.bashrc"
grepadd "export QT_X11_NO_MITSHM=1" "$CHUSERHOME/.bashrc"

multilinereplace "$INSTALLPATH/usr/local/bin/sx" <<'EOL'
#!/bin/bash
USERNAMEVAR=$(id 1000 -un)
DISPLAY=$DISPLAY su $USERNAMEVAR -c xterm &
EOL
