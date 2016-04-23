#!/bin/bash

echo "Executing YHFBackupMega.sh."

# Enable error halting.
set -e

# Set normal user.
if [ "$USER" != "root" ]; then
	export USERNAMEVAR=$USER
else
	export USERNAMEVAR=$(id 1000 -un)
fi

export USERGROUP=$(id $USERNAMEVAR -gn)
export USERHOME=/home/$USERNAMEVAR
if [ ! -d $USERHOME ]; then
	echo "User home not found. Exiting."
	exit 1;
fi
echo "Username is $USERNAMEVAR"
echo "User home is $USERHOME"

#By default use MEGA.
MEGA=1

checkdeps () {
	DEP="xz tar split cat id megarm megals megacopy openssl hostnamectl"
	for D in $DEP
	do
		type $D > /dev/null 2>&1 || { echo "$D is not ready" 1>&2; exit 1; }
	done
}

usage () {
	echo "h - help"
	echo "b - backup"
	echo "r - restore"
	echo "p - password"
	echo "l - location of custom backup path"
	echo "s - custom hostname"
	echo "t - use default hostname"
	exit 0;
}

initvariables () {
	MEGASTOREFOLDER="/Root/Backups"
	if [ $MEGA = 1 ]; then
		LOCALBACKUPFOLDER="$(readlink -f ./${HOSTNAME})"
	fi
	if [ $MEGA = 0 ]; then
		LOCALBACKUPFOLDER="$(readlink -f ${NEWBACKUPFOLDER}/${HOSTNAME})"
	fi
}

setxzopts () {
	MACHINEARCH=$(uname -m)
	if [ "${MACHINEARCH}" = "armv7l" ]; then
		export XZ_OPT=-1
	else
		export XZ_OPT=-T0
	fi
}

testmega () {
	[[ ! $(type -p megadf) && $(type -p yaourt) ]] && yaourt -S --noconfirm megatools
	[[ ! $(type -p megadf) && $(type -p apt-get) ]] && apt-get install -y megatools
	if ! megadf >> /dev/null; then
		echo "Mega is not accessible. Please check using megadf. Exiting."
		echo "As a reference, the template for ~/.megarc is as follows:"
		echo "[Login]"
		echo "Username = emailaddress"
		echo "Password = password"
		exit 1;
	fi
}

checkmegabackup () {
	MEGABACKUPFOLDER="$MEGASTOREFOLDER/$HOSTNAME"
	MEGABACKUPFOLDEREXISTS="$(megals $MEGASTOREFOLDER/$HOSTNAME)"
}

cleanmega () {
	checkmegabackup
	if [ ! -z "${MEGABACKUPFOLDEREXISTS}" ]; then
		echo "Removing existing local backup ${MEGABACKUPFOLDEREXISTS}."
		megarm "${MEGABACKUPFOLDER}"
	fi
}

cleanlocal () {
	if [ -d "${LOCALBACKUPFOLDER}" ]; then
		echo "Removing existing local backup ${LOCALBACKUPFOLDER}."
		rm -rf "${LOCALBACKUPFOLDER}"
	fi
}

createlocalfld () {
	if [ ! -d "${LOCALBACKUPFOLDER}" ]; then
		echo "Creating ${LOCALBACKUPFOLDER}"
		mkdir "${LOCALBACKUPFOLDER}"
		chmod a+rwx "${LOCALBACKUPFOLDER}"
	fi
}

copyfrommega () {
	cleanlocal
	sync
	checkmegabackup
	if [ ! -z "${MEGABACKUPFOLDEREXISTS}" ]; then
		createlocalfld
		echo "Copying ${MEGABACKUPFOLDER} to ${LOCALBACKUPFOLDER}."
		megacopy --download --remote "${MEGABACKUPFOLDER}" --local "${LOCALBACKUPFOLDER}"
	fi
}

copytomega () {
	sync
	cleanmega
	echo "Copying ${LOCALBACKUPFOLDER} to ${MEGASTOREFOLDER}."
	megamkdir "$MEGABACKUPFOLDER"
	megacopy --remote "${MEGABACKUPFOLDER}" --local "${LOCALBACKUPFOLDER}"
}

initbackupvars () {
	echo "Backup to $TAR chosen."
	if [[ $MEGA = 0 && ! -d "$(dirname ${BACKUPFOLDER})" ]]; then
		echo "No root folder $(dirname ${BACKUPFOLDER}) found. Exiting."
		exit 1;
	else
		echo "Backing up folders to $BACKUPFOLDER"
	fi
	# Initialize tar command
	TARBAKCMD="tar cvpJ"
	SPLITBAKCMD="split -b 245M - ${TAR}-"
	SSLBAKCMD="openssl enc -aes256 -e -pass pass:${PASSWORD}"
}

initrestorevars () {
	echo "Restore from $TAR chosen."
	if [[ $MEGA = 1 ]]; then
		checkmegabackup
	fi
	if [[ $MEGA = 1 && -z "$MEGABACKUPFOLDER" ]]; then
		echo "No restore file found. Please re-run script and choose a valid hostname or backup location."
		exit 1;
	fi
	if [[ $MEGA = 0 && ! -f "${TAR}-aa" ]]; then
		BACKUPCHOICE=0
		echo "No restore file found. Please re-run script and choose a valid hostname or backup location."
		exit 1;
	fi

	RESTOREFOLDER="${USERHOME}"
	read -p "Input a restore folder (Default is $RESTOREFOLDER): " NEWRESTOREFOLDER
	if [ -z "$NEWRESTOREFOLDER" ]; then
		echo "No input found. Defaulting to $RESTOREFOLDER."
	else
		NEWRESTOREFOLDER="$(readlink -f ${NEWRESTOREFOLDER%/})"
	fi
	if [ -d "$NEWRESTOREFOLDER" ]; then
		echo "Setting restore folder to ${NEWRESTOREFOLDER}"
		RESTOREFOLDER="${NEWRESTOREFOLDER}"
	fi

	if [ ! -d "${RESTOREFOLDER}" ]; then
		echo "Restore folder ${RESTOREFOLDER} not found. Exiting."
		exit 1;
	else
		echo "Restore to ${RESTOREFOLDER}"
	fi

	TARRESTORECMD="tar xvpJ -C ${RESTOREFOLDER}"
	SPLITRESCMD="cat $TAR-*"
	SSLRESCMD="openssl enc -aes256 -d -pass pass:${PASSWORD}"
}

# Compose tar command function
composetarcmd () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		DIRTOBACKUP="$1"
	fi

	if [ -d "$USERHOME/$DIRTOBACKUP" ]; then
		echo "Adding $USERHOME/$DIRTOBACKUP to backup command."
		TARBAKCMD="${TARBAKCMD} -C $USERHOME $DIRTOBACKUP"
	else
		echo "Folder $USERHOME/$DIRTOBACKUP not found. Not backing up."
	fi
}

fulltarcmd () {
	# Cache folder
	composetarcmd ".cache/banshee-1"
	composetarcmd ".cache/google-chrome"
	composetarcmd ".cache/chromium"
	composetarcmd ".cache/mozilla"
	composetarcmd ".cache/qBittorrent"
	composetarcmd ".cache/thunderbird"

	# Config Folder
	composetarcmd ".config/banshee-1"
	composetarcmd ".config/Clementine"
	composetarcmd ".config/google-chrome"
	composetarcmd ".config/chromium"
	composetarcmd ".config/pulse"
	composetarcmd ".config/qBittorrent"
	composetarcmd ".config/syncthing"
	composetarcmd ".config/syncthing-gtk"
	composetarcmd ".config/VirtualBox"
	composetarcmd ".config/mupen64plus"

	# Misc
	composetarcmd ".local/share/data/ownCloud"
	composetarcmd ".local/share/mupen64plus"
	composetarcmd ".fceux"
	composetarcmd ".dolphin-emu"
	composetarcmd ".areca"
	composetarcmd ".mozilla"
	composetarcmd ".thunderbird"
	composetarcmd ".ssh"
	composetarcmd ".vnc"
	composetarcmd ".lastpass"
	composetarcmd ".snes9x"
	composetarcmd ".vmware"
	composetarcmd ".VeraCrypt"
	composetarcmd "Desktop"

	echo ""
	echo "Tar arguments: ${TARBAKCMD}"
}

# Get Hostname
if [ $(type -P hostnamectl) ]; then
	HOSTNAME="$(hostnamectl --static)"
elif [ -f /etc/hostname ]; then
	HOSTNAME="$(cat /etc/hostname)"
fi

if [ ! -z $HOSTNAME ]; then
	echo "Hostname detected as $HOSTNAME."
else
	echo "Hostname not detected."
fi

# Get options
while getopts ":hbrp:l:s:t" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		b)
			BACKUPCHOICE=1
			;;
		r)
			BACKUPCHOICE=2
			;;
		p)
			PASSWORD="$OPTARG"
			;;
		l)
			NEWBACKUPFOLDER="$OPTARG"
			NEWBACKUPFOLDER=$(readlink -f "${NEWBACKUPFOLDER%/}")
			MEGA=0
			;;
		s)
			NEWHOSTNAME="$OPTARG"
			;;
		t)
			NEWHOSTNAME="$HOSTNAME"
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

if [ -z "$NEWHOSTNAME" ]; then
	read -p "Input a hostname (if you want to change the above name): " NEWHOSTNAME
	NEWHOSTNAME=${NEWHOSTNAME//[^a-zA-Z0-9_]/}
fi
if [[ -z "$NEWHOSTNAME" && ! -z "$HOSTNAME" ]]; then
	echo "No input found. Defaulting to $HOSTNAME."
elif [[ ! -z "$NEWHOSTNAME" ]]; then
	echo "Setting $NEWHOSTNAME as hostname."
	HOSTNAME="$NEWHOSTNAME"
elif [[ -z "$NEWHOSTNAME" && -z "$HOSTNAME" ]]; then
	echo "No hostname found at all. Exiting."
	exit 1;
fi


if [ -z "$PASSWORD" ]; then
	echo "Input a password: "
	read -s PASSWORD
	echo "Please confirm password: "
	read -s PASSWORD2
	if [[ -z "$PASSWORD" ]]; then
		echo "No password found. Exiting."
		exit 1;
	fi
	if [[ "$PASSWORD" != "$PASSWORD2" ]]; then
		echo "Passwords do not match. Exiting."
		exit 1;
	fi
fi

initvariables
setxzopts
if [[ -z "$NEWBACKUPFOLDER" ]]; then
	echo "No input found. Defaulting to MEGA."
	MEGA=1
elif [ -d "$NEWBACKUPFOLDER" ]; then
	echo "Setting backup folder to ${NEWBACKUPFOLDER}"
	BACKUPFOLDER="${NEWBACKUPFOLDER}"
	MEGA=0
else
	echo "Invalid folder detected. Defaulting to MEGA."
	MEGA=1
fi
initvariables

if [ $MEGA != 0 ]; then
	testmega
fi
BACKUPFOLDER="$LOCALBACKUPFOLDER"
TAR="$BACKUPFOLDER/$HOSTNAME.tar.xz"

[ -z $BACKUPCHOICE ] && BACKUPCHOICE="0"
while [[ "${BACKUPCHOICE}" -le "0" || "${BACKUPCHOICE}" -gt "2" ]]; do
    read -p "Choose an option (1=Backup, 2=Restore)" BACKUPCHOICE
    case $BACKUPCHOICE in
    [1] )
		#~ initbackupvars
		echo "Choice is Backup."
	;;
	[2] )
		#~ initrestorevars
		echo "Choice is Restore."
	;;
	* )
	echo "Please input a valid number."
	;;
    esac
done

[ $BACKUPCHOICE = 1 ] && initbackupvars
[ $BACKUPCHOICE = 2 ] && initrestorevars

echo "Hostname is $HOSTNAME"
echo "Mega is $MEGA."
echo "Backup file is $TAR"

read -p "Press any key to continue."
echo ""

if [[ "$BACKUPCHOICE" -eq "1" ]]; then
	echo "Performing Backup."

	fulltarcmd

	if [[ $MEGA = 1 ]]; then
		testmega
		cleanmega
	fi
	cleanlocal
	createlocalfld

	${TARBAKCMD} | ${SSLBAKCMD} | ${SPLITBAKCMD}

	if [[ $MEGA = 1 ]]; then
		copytomega
		cleanlocal
	fi
	sync

elif [[ "$BACKUPCHOICE" -eq "2" ]]; then
	echo "Performing Restore."

	if [[ $MEGA = 1 ]]; then
		cleanlocal
		copyfrommega
	fi

	${SPLITRESCMD} | ${SSLRESCMD} | ${TARRESTORECMD}

	if [[ $MEGA = 1 ]]; then
		cleanlocal
	fi
	sync
fi
