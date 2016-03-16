#!/bin/bash
# Yusbbackup.sh, borg-backup version.

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

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

function usage()
{
cat <<EOF
Usage: sudo $0 [Path to root of Backup drive] [Path to BORG folder on destination drive] [Paths to backup]
Example: sudo Yusbbackup.sh "/mnt/Backup" "/mnt/Backup/borg" "/mnt/Storage/Files" "/mnt/Storage/DLs"

EOF
exit 1;
}

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
		NEWPATH="$(readlink -f $1)"
	fi

	BORGFOLDERS="${BORGFOLDERS} ${NEWPATH}"
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
echo "Ensure the borg Destination Path has been initialized before running the backup script."
echo -e "borg source folders to backup: $BORGFOLDERS"
echo ""
read -p "Press any key to create script."

if [[ ! $(type -P borg) ]]; then
	echo "Installing borg."
	[ $(type -p pacman) ] && sudo pacman -S --needed --noconfirm borg python-llfuse
fi

#Install scripts if they are not present yet.
# SIGINT Kill signal is used to make borg remove lock on backup target.
echo "Creating $SDPATH/$SDSERVICE."
bash -c "cat >$SDPATH/$SDSERVICE" <<EOL
[Unit]
After=${SYSTEMDMNT}

[Service]
ExecStart=${HDSCRIPT}
User=${USERNAMEVAR}
KillSignal=SIGINT

[Install]
WantedBy=${SYSTEMDMNT}
EOL
systemctl daemon-reload
systemctl enable "$SDSERVICE"

multilinereplace "$HDSCRIPT" <<EOL
#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="\${BASH_SOURCE[0]}"
FLWSOURCE="\$(readlink -f "\$SCRIPTSOURCE")"
SCRIPTDIR="\$(dirname "\$FLWSOURCE")"
SCRNAME="\$(basename \$SCRIPTSOURCE)"
echo "Executing \${SCRNAME}."

set -eu

if [[ ! \$(type -P borg) ]]; then
	echo "No borg command found. Exiting."
	exit 1
fi

initvars () {
	HDPATH="$HDPATH"
	HDSTATUS="\$(systemctl is-active \$HDPATH)"
	if [ "\$HDSTATUS" != "active" ]; then
		echo "Hard drive \$HDPATH not mounted. Exiting."
		exit 1
	fi

	BORGFOLDERS="$(echo -e $BORGFOLDERS)"

	DESTPATH="$DESTPATH"
	if [ ! -d "\$DESTPATH" ]; then
		echo "Destination path \$DESTPATH not found. Exiting."
		exit 1
	fi
}

#Wait 5 seconds.
sleep 5

initvars

# Clear the lock if borg is not running and lock folder exists.
if [[ ! \$(pgrep borg) && -d "\$DESTPATH/lock.exclusive" ]]; then
	borg break-lock "\$DESTPATH"
fi

# Exit if Borg is running
if [[ \$(pgrep borg) ]]; then
	echo "Borg is currently running at process \$(pgrep borg). Exiting."
	exit 0
fi

echo "Sync begin."

if [[ -d "\$DESTPATH" ]]; then
	# Backup all included folders
	borg create -vs --list -C lz4 \$DESTPATH::\`hostname\`-\`date +%Y-%m-%d_%H%M\` \$BORGFOLDERS --exclude '*/.stversions*' --exclude '*/VMs*'

	# Use the \`prune\` subcommand to maintain 26 weeks of
	# archives of THIS machine. --prefix `hostname`- is very important to
	# limit prune's operation to this machine's archives and not apply to
	# other machine's archives also.
	borg prune -v \$DESTPATH --prefix \`hostname\`- –keep-within 26w
else
	echo "Destination \$DESTPATH path not found. Exiting."
fi

sync || true

echo “Backup successfully completed on \$(date).”
EOL

echo "Script completed successfully."
