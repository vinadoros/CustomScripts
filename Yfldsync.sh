#!/bin/bash

# Disable error handling
set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

usage () {
	echo "h - help"
	echo "s - source folder"
	echo "d - destination folder"
	echo "a - disable attribute and ACL checks"
	echo "p - ssh port"
	exit 0;
}


composersync () {
	if [ ! -z "$SSHPORT" ]; then
		SSHCMD="-e \"ssh -p $SSHPORT\""
	else
		SSHCMD=""
	fi
}

# Rsync dry run function
rsyncdryrun () {
	echo "Test sync."
	if [ ! -z "$DISABLEATTRCHK" ]; then
		TESTRSYNCOPTS="-axHnvi"
	else
		TESTRSYNCOPTS="-axHAXnvi"
	fi
	if [ ! -z "$SSHPORT" ]; then
		sudo rsync $TESTRSYNCOPTS --numeric-ids --del -e "ssh -p $SSHPORT" "$FOLDERONE" "$FOLDERTWO"
	else
		sudo rsync $TESTRSYNCOPTS --numeric-ids --del "$FOLDERONE" "$FOLDERTWO"
	fi
	echo "Test sync complete."

	echo -e "\nFolder one: $FOLDERONE"
	echo -e "Folder two: $FOLDERTWO\n"

}

# Compose rsync command function
rsyncrealcmd () {
	sudo bash <<EOF
	if [ ! -z "$DISABLEATTRCHK" ]; then
		REALRSYNCOPTS="-axH"
	else
		REALRSYNCOPTS="-axHAX"
	fi
	if [ ! -z "$SSHPORT" ]; then
		rsync \$REALRSYNCOPTS --info=progress2 --numeric-ids --del -e "ssh -p $SSHPORT" "$FOLDERONE" "$FOLDERTWO"
	else
		rsync \$REALRSYNCOPTS --info=progress2 --numeric-ids --del "$FOLDERONE" "$FOLDERTWO"
	fi
	echo -e "\nSynching disks."
	sync
EOF
}

# Get options
while getopts "ahs:d:p:" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		s)
			FOLDERONE="$OPTARG"
			;;
		d)
			FOLDERTWO="$OPTARG"
			;;
		p)
			SSHPORT="$OPTARG"
			;;
		a)
			DISABLEATTRCHK=1
			;;
		\?)
			echo "Invalid option: -$OPTARG" 1>&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument" 1>&2
			exit 1
			;;
	esac
done

if [[ -z "$FOLDERONE" || -z "$FOLDERTWO" ]]; then
	echo "Enter valid folders."
	usage
	exit 1;
fi

composersync

set -e

rsyncdryrun

read -p "Press any key to sync."
echo ""

rsyncrealcmd

echo -e "\nScript completed successfully.\n"
