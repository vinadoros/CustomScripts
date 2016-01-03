#!/bin/bash
# Yusbbackup.sh version 2.

function usage()
{
cat <<EOF
Usage: sudo $0 [Path to root of Backup drive] [Path to RDIFF folder on destination drive] [Paths to backup]
Example: sudo Yusbbackup.sh "/mnt/Backup" "/mnt/Backup/Rdiff" "/mnt/Storage/Files" "/mnt/Storage/DLs"

EOF
exit 1;
}

if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
	USERNAMEVAR="$SUDO_USER"
elif [ "$USER" != "root" ]; then
	USERNAMEVAR="$USER"
else
	USERNAMEVAR="$(id 1000 -un)"
fi

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	usage
fi

if [ -z "$1" ]; then
	echo "Error, no location selected. Exiting."
	usage
else
	HDPATH="$1"
	HDPATH="$(readlink -f $HDPATH)"
	echo "Using ${HDPATH} as drive path."
fi

if [ -z "$2" ]; then
	echo "Error, no destination selected. Exiting."
	usage
else
	DESTPATH="$2"
	DESTPATH="$(readlink -f $DESTPATH)"
	echo "Using ${DESTPATH} as backup destination path."
fi

getvars() {
	BASEPATH="$(basename $HDPATH)"
	# Remove spaces from basepath.
	BASEPATH="${BASEPATH//[[:blank:]]/}"
	
	# Get mount device in /dev
	#DEVDRIVE="$(mount | grep "${HDPATH}" | awk -F" " '{ print $1 }')"
	
	# Get systemd mount name.
	SYSTEMDMNT="$(systemctl | grep "${HDPATH}" | awk -F" " '{ print $1 }')"	
	
	HDSCRIPT="/usr/local/bin/usbbak-${BASEPATH}.sh"
	SDPATH="/etc/systemd/system"
	SDSERVICE="usbbak-${BASEPATH}.service"
	
}

setsourcefoldercmd () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		NEWPATH="$1"
	fi
	
	# Inputs a path, finds the block device associated with it using df.
	# Feeds it into lsblk to output the UUID, and cuts off characters after the dash.
	# This makes the folder names unique, even if they are the same name across devices.
	UUIDCUT="$(lsblk -n -o UUID $(df --output=source $NEWPATH|tail -1) | cut -d"-" -f1)"
	NEWPATHBASE="$UUIDCUT-$(basename $NEWPATH)"
	
	RDIFFCMD="${RDIFFCMD}\nrdiffbak \"$NEWPATH\" \"\$DESTPATH/$NEWPATHBASE\""
}

getvars

# Process paths after the first two arguments.
# https://stackoverflow.com/questions/2701400/remove-first-element-from-in-bash#2701420
for PATHNAMES in "${@:3}"
do
	if [ -d "$PATHNAMES" ]; then
		setsourcefoldercmd "$PATHNAMES"
	else
		echo "$PATHNAMES folder not found. Not adding."
	fi
done

set -eu

echo "Normal user: $USERNAMEVAR"
echo "Script path: $HDSCRIPT"
echo "Device service: $SYSTEMDMNT"
echo "Systemd Service: $SDPATH/$SDSERVICE"
echo "Destination Path: $DESTPATH"
echo -e "Rdiff cmd: $RDIFFCMD"
echo ""
read -p "Press any key to create script."

if [[ ! $(type -P rdiff-backup) ]]; then
	echo "Installing rdiff-backup."
	[ $(type -p pacman) ] && sudo pacman -S --needed --noconfirm rdiff-backup pylibacl
fi

#Install scripts if they are not present yet.
#Command to list usb devices seen by systemd: systemctl --all --full -t device
#Taken from: https://bbs.archlinux.org/viewtopic.php?id=149419
#Actually above is not used below. Instead used mount target for systemd.
echo "Creating $SDPATH/$SDSERVICE."
bash -c "cat >$SDPATH/$SDSERVICE" <<EOL
[Unit]
After=${SYSTEMDMNT}

[Service]
ExecStart=${HDSCRIPT}
User=${USERNAMEVAR}

[Install]
WantedBy=${SYSTEMDMNT}
EOL
systemctl daemon-reload
systemctl enable "$SDSERVICE"

echo "Creating $HDSCRIPT"
bash -c "cat >$HDSCRIPT" <<EOL
#!/bin/bash
set -eu

if [[ ! \$(type -P rdiff-backup) ]]; then
	echo "No rdiff-backup found. Exiting."
	exit 1;
fi

initvars () {
	HDPATH="$HDPATH"
	HDSTATUS="\$(systemctl is-active \$HDPATH)"
	if [ "\$HDSTATUS" != "active" ]; then
		echo "Hard drive \$HDPATH not mounted. Exiting."
		exit 1
	fi
	
	DESTPATH="$DESTPATH"
	if [ ! -d "\$DESTPATH" ]; then
		echo "Destination path \$DESTPATH not found. Exiting."
		exit 1
	fi
}

rsyncfunc () {
	
	if [ -z "\$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		SOURCEPATH="\$1"
	fi
	
}

rdiffbak () {
	
	if [ -z "\$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		SOURCEPATH="\$1"
	fi
	
	if [ -z "\$2" ]; then
		echo "No parameter passed."
		return 1;
	else
		DESTINATIONPATH="\$2"
	fi
	
	if [ ! -d "\$DESTINATIONPATH" ]; then
		echo "Creating \$DESTINATIONPATH."
		mkdir -p "\$DESTINATIONPATH"
		chmod a+rwx "\$DESTINATIONPATH"
	fi
	
	if [ -d "\$SOURCEPATH" ]; then
		rdiff-backup -v5 --force --no-compression --exclude '**/.stversions**' --exclude '**/VMs**' "\$SOURCEPATH" "\$DESTINATIONPATH" 
		rdiff-backup -v5 --remove-older-than 26W "\$DESTINATIONPATH"
	else
		echo "\$SOURCEPATH not found. Not syncing."
	fi
	
	sync
}

#Wait 5 seconds.
sleep 5

initvars

echo "Sync begin."

$(echo -e $RDIFFCMD)

echo "Backup finished successfully."
EOL
chmod a+rwx "$HDSCRIPT"


echo "Script completed successfully."

