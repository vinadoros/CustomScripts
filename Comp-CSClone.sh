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
# Default variables.
REPO="vinadoros/CustomScripts"
CLONEPATH="/opt"

usage () {
	echo "h - help"
	echo "r - Github repo (i.e. $REPO)"
	echo "p - Base path on comptuer (i.e. $CLONEPATH)"
	exit 0;
}

# Get options
while getopts ":r:p:h" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		r)
			REPO="$OPTARG"
			;;
		p)
			CLONEPATH="$OPTARG"
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

function clonerepo {
	if [[ -z $1 || -z $2 ]]; then
		echo "Not enough paramters. Exiting."
		return;
	fi
	GITHUBREPO="$1"
	LOCATION="$2"

	# Save the repo name (after the slash).
	REPONAME="${GITHUBREPO##*/}"

	# If passed a folder, use it.
	if [ -d "$LOCATION" ]; then
		ROOTFOLDER="$(readlink -f $LOCATION)"
		if [ "$(basename $ROOTFOLDER)" = "$REPONAME" ]; then
			ROOTFOLDER="$(dirname $ROOTFOLDER)"
		fi
	else
		ROOTFOLDER="/opt"
	fi
	echo "Repo is $GITHUBREPO. Cloning to $ROOTFOLDER/$REPONAME."

	cd "$ROOTFOLDER"

	if [ ! -d "$REPONAME" ]; then
		git clone https://github.com/"$GITHUBREPO".git
	fi

	cd "$ROOTFOLDER/$REPONAME"
	git config remote.origin.url "https://github.com/${GITHUBREPO}.git"
	git pull

	if [[ ! -z "$GITHUBCOMMITNAME" && ! -z "$GITHUBCOMMITEMAIL" && -f "$GITHUBRSAPUB" ]]; then
		echo "Adding commit information for $REPONAME github account."
		git config remote.origin.url "git@gitserv:${GITHUBREPO}.git"
		git config push.default simple
		git config user.name "${GITHUBCOMMITNAME}"
		git config user.email "${GITHUBCOMMITEMAIL}"
	fi

	# Update scripts folder every hour.
	if [ -d "/etc/cron.hourly" ]; then
		multilinereplace "/etc/cron.hourly/update${REPONAME}" << EOFXYZ
	#!/bin/bash
	echo "Executing \$0"
	su $USERNAMEVAR -s /bin/bash <<'EOL'
cd $ROOTFOLDER/${REPONAME}
git pull
EOL
EOFXYZ
	fi

	chown "$USERNAMEVAR":"$USERGROUP" -R "$ROOTFOLDER/${REPONAME}"
	chmod a+rwx "$ROOTFOLDER/${REPONAME}"

}

clonerepo "$REPO" "$CLONEPATH"
