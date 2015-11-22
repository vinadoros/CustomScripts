#!/bin/bash

echo "Executing Yfldsync.sh."

usage () {
	echo "h - help"
	echo "s - source folder"
	echo "d - destination folder"
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
	if [ ! -z "$SSHPORT" ]; then
		sudo rsync -axHAXnvi --numeric-ids --del -e "ssh -p $SSHPORT" "$FOLDERONE" "$FOLDERTWO"
	else
		sudo rsync -axHAXnvi --numeric-ids --del "$FOLDERONE" "$FOLDERTWO"
	fi
	echo "Test sync complete."

	echo -e "\nFolder one: $FOLDERONE"
	echo -e "Folder two: $FOLDERTWO\n"

}

# Compose rsync command function
rsyncrealcmd () {
	sudo bash <<EOF
	if [ ! -z "$SSHPORT" ]; then
		rsync -axHAX --info=progress2 --numeric-ids --del -e "ssh -p $SSHPORT" "$FOLDERONE" "$FOLDERTWO"
	else
		rsync -axHAX --info=progress2 --numeric-ids --del "$FOLDERONE" "$FOLDERTWO"
	fi
	echo -e "\nSynching disks."
	sync
EOF
}

# Get options
while getopts "hs:d:p:" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		s)
			FOLDERONE="$OPTARG"
			if [ -d "$FOLDERONE" ]; then
				FOLDERONE="$(readlink -f "$FOLDERONE")"
			fi
			;;
		d)
			FOLDERTWO="$OPTARG"
			if [ -d "$FOLDERTWO" ]; then
				FOLDERTWO="$(readlink -f "$FOLDERTWO")"
			fi
			;;
		p)
			SSHPORT="$OPTARG"
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
