#!/bin/bash

# Disable error handling
set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

TEMPFOLDERPATH="/mnt"
TEMPFOLDERHEADER="borgmount"

usage () {
	echo "h - help"
	echo "s - borg backup folder"
	echo "b - name of borg backup in borg backup folder"
	echo "d - destination folder"
	echo "c - compare two borg backups"
	echo "f - dry run compare only"
	exit 0;
}

safermfld () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		RMFLD="$1"
	fi

	if [[ -z $(ls "$RMFLD") ]]; then
		echo "Removing $RMFLD"
		sudo rm -rf "$RMFLD"
	else
		echo "$RMFLD is not empty. Not removing."
		sudo ls -la "$RMFLD"
	fi
}

borgumount () {

	if [ ! -d "$1" ]; then
		echo "No valid folder to unmount."
		return 1;
	else
		BORGMOUNT="$1"
	fi

	# Unmount the borg backup. If this fails, do a lazy umount.
	fusermount -u "$BORGMOUNT" || fusermount -z "$BORGMOUNT"

	# Delete the temporary folder after unmounting it.
	safermfld "$BORGMOUNT"
}

borgcleanup () {
	for mntfolders in "${TEMPFOLDERPATH}/${TEMPFOLDERHEADER}-"*; do
		if [ -d "$mntfolders" ]; then
			echo "Cleaning up $mntfolders"
			borgumount "$mntfolders"
		fi
	done
}

# Generate random folder names
randomfolder() {
	# Generate a random 8 character string
	RANDOMSTRING=$( cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w6 | head -n1 )
	# Set temporary folder
	FULLTEMPFOLDER="${TEMPFOLDERPATH}/${TEMPFOLDERHEADER}-${RANDOMSTRING}"
}

# Borg List function
borglist () {
	if [ -d "$BORGBACKUPFOLDER" ]; then
		echo "These are the available backups."
		borg list "$BORGBACKUPFOLDER"
	else
		echo "No backup folder specified."
		usage
		exit 1;
	fi
}

# Borg Mount function
borgmount () {

	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		BORGBACKUP="$1"
	fi

	if [ -z "$2" ]; then
		echo "No parameter passed."
		return 1;
	else
		MOUNTFOLDER="$2"
	fi

	echo "Mount borg folder."
	if [[ ! -z "$BORGBACKUP" && -d "$BORGBACKUPFOLDER" ]]; then
		sudo mkdir -p "$MOUNTFOLDER"
		sudo chmod a+rwx "$MOUNTFOLDER"
		borg mount "$BORGBACKUPFOLDER"::"$BORGBACKUP" "$MOUNTFOLDER"
	else
		echo "No folder or backup specified. Exiting."
		exit 1;
	fi

}

# Rsync dry run function
rsyncdryrun () {
	echo "Test sync."
	TESTRSYNCOPTS="-axHAXnvi"
	rsync $TESTRSYNCOPTS --exclude='.stversions' --numeric-ids --del "$FOLDERONE" "$FOLDERTWO"
	echo "Test sync complete."

	echo -e "\nFolder one: $FOLDERONE"
	echo -e "Folder two: $FOLDERTWO\n"
}

# Compose rsync command function
rsyncrealcmd () {
	REALRSYNCOPTS="-axHAX"
	rsync \$REALRSYNCOPTS --exclude='.stversions' --info=progress2 --numeric-ids --del "$FOLDERONE" "$FOLDERTWO"
	echo -e "\nSynching disks."
	sync
}

if [[ -z "$@" ]]; then
	usage
	exit 0;
fi

# Get options
while getopts "hs:b:d:cfx:y:" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		s)
			BORGBACKUPFOLDER="$OPTARG"
			;;
		b)
			BORGBACKUPNAME="$OPTARG"
			;;
		d)
			DESTFOLDER="$OPTARG"
			;;
		c)
			OPTION=2
			;;
		f)
			OPTION=3
			;;
		x)
			BORGBACKUPNAMEONE="$OPTARG"
			;;
		y)
			BORGBACKUPNAMETWO="$OPTARG"
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

trap borgcleanup SIGHUP SIGINT SIGTERM

set -e

if [ -z $OPTION ]; then
	# Set mount folder
	randomfolder
	BORGFOLDERMOUNTONE="$FULLTEMPFOLDER"

	if [ -z "$BORGBACKUPNAME" ]; then
		borglist
		read -p "Input a backup from the above list: " BORGBACKUPNAME
	fi

	# Mount the backup
	borgmount "$BORGBACKUPNAME" "$BORGFOLDERMOUNTONE"

	# Perform dry run and sync.
	FOLDERONE="$BORGFOLDERMOUNTONE/$DESTFOLDER"
	FOLDERTWO="$DESTFOLDER"
	rsyncdryrun
	if [[ $OPTION -ne 2 ]]; then
		read -p "Press y to sync or enter to not sync: " QU
		if [[ $QU = [Yy] ]]; then
			echo ""
			rsyncrealcmd
		fi
	fi

	# Unmount and remove the temporary borg mount.
	borgumount "$BORGFOLDERMOUNTONE"
elif [ $OPTION -eq 3 ]; then
	echo "Comparing borg backups."
	# Set mount folder
	randomfolder
	BORGFOLDERMOUNTONE="$FULLTEMPFOLDER"
	randomfolder
	BORGFOLDERMOUNTTWO="$FULLTEMPFOLDER"

	borglist
	[ -z "$BORGBACKUPNAMEONE" ] && read -p "Input first backup from the above list: " BORGBACKUPNAMEONE
	[ -z "$BORGBACKUPNAMETWO" ] && read -p "Input second backup from the above list: " BORGBACKUPNAMETWO

	# Mount the backup
	borgmount "$BORGBACKUPNAMEONE" "$BORGFOLDERMOUNTONE"
	borgmount "$BORGBACKUPNAMETWO" "$BORGFOLDERMOUNTTWO"

	# Perform dry run.
	FOLDERONE="$BORGFOLDERMOUNTONE/"
	FOLDERTWO="$BORGFOLDERMOUNTTWO/"
	rsyncdryrun

	# Unmount and remove the temporary borg mount.
	borgumount "$BORGFOLDERMOUNTONE"
	borgumount "$BORGFOLDERMOUNTTWO"
fi

# Cleanup everything (just in case)
borgcleanup

echo -e "\nScript completed successfully.\n"
