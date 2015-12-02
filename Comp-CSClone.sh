#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

# Add general functions if they don't exist.
type -t grepadd >> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

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

# Private variable file.
PRIVATEVARS="/usr/local/bin/privateconfig.sh"
if [ -f $PRIVATEVARS ]; then
	source "$PRIVATEVARS"
fi

# If passed a folder, use it.
if [ -d "$1" ]; then
	CSROOTFOLDER="$(readlink -f $1)"
	if [ "$(basename $CSROOTFOLDER)" = "CustomScripts" ]; then
		CSROOTFOLDER="$(dirname $CSROOTFOLDER)"
	fi
else
	CSROOTFOLDER="/opt"
fi
echo "CSRootFolder is $CSROOTFOLDER."

set -e

cd "$CSROOTFOLDER"

if [ ! -d "CustomScripts" ]; then
	git clone https://github.com/vinadoros/CustomScripts.git
fi

cd "$CSROOTFOLDER/CustomScripts"
git config remote.origin.url "https://github.com/vinadoros/CustomScripts.git"
git pull

if [[ ! -z "$GITHUBCOMMITNAME" && ! -z "$GITHUBCOMMITEMAIL" && -f "$GITHUBRSAPUB" ]]; then
	echo "Adding commit information for CustomScripts github account."
	git config remote.origin.url "git@gitserv:vinadoros/CustomScripts.git"
	git config push.default simple
	git config user.name "${GITHUBCOMMITNAME}"
	git config user.email "${GITHUBCOMMITEMAIL}"
fi

# Update scripts folder every hour using fcron.
if type -p fcrontab &> /dev/null; then
	grepcheckadd "&b 0 * * * * \"cd $CSROOTFOLDER/CustomScripts; git pull\"" "cd $CSROOTFOLDER/CustomScripts; git pull" "/var/spool/fcron/$USERNAMEVAR.orig"
	chown fcron:fcron "/var/spool/fcron/$USERNAMEVAR.orig"
	su - "$USERNAMEVAR" -c "fcrontab -z"
fi

chown "$USERNAMEVAR":"$USERGROUP" -R "$CSROOTFOLDER/CustomScripts"
chmod a+rwx "$CSROOTFOLDER/CustomScripts"
