#!/bin/bash

echo "Executing YHFBackup.sh."

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

# Set XZ Options
# CPU Cores available
MACHINEARCH="$(uname -m)"
if [ "$MACHINEARCH" = "armv7l" ]; then
	CPUCORES=1
else
	CPUCORES=$(grep -c ^processor /proc/cpuinfo)
fi


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

read -p "Input a hostname (if you want to change the above name): " NEWHOSTNAME
NEWHOSTNAME=${NEWHOSTNAME//[^a-zA-Z0-9_]/}
if [[ -z "$NEWHOSTNAME" && ! -z "$HOSTNAME" ]]; then
	echo "No input found. Defaulting to $HOSTNAME."
elif [[ ! -z "$NEWHOSTNAME" ]]; then
	echo "Setting $NEWHOSTNAME as hostname."
	HOSTNAME="$NEWHOSTNAME"
elif [[ -z "$NEWHOSTNAME" && -z "$HOSTNAME" ]]; then
	echo "No hostname found at all. Exiting."
	exit 1;
fi

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


BACKUPFOLDER="/media/Box/Backups"
#BACKUPFOLDER="$USERHOME/temp2"
read -p "Input a backup location (Default is $BACKUPFOLDER): " NEWBACKUPFOLDER
NEWBACKUPFOLDER=$(readlink -f "${NEWBACKUPFOLDER%/}")
if [[ -z "$NEWBACKUPFOLDER" ]]; then
	echo "No input found. Defaulting to $BACKUPFOLDER."
	export XZ_OPT=-9
elif [ -d "$NEWBACKUPFOLDER" ]; then
	echo "Setting backup folder to ${NEWBACKUPFOLDER}"
	BACKUPFOLDER="${NEWBACKUPFOLDER}"
	export XZ_OPT=-9T"$CPUCORES"
fi

TAR="$BACKUPFOLDER/$HOSTNAME.tar.xz"

BACKUPCHOICE="0"
while [[ "${BACKUPCHOICE}" -le "0" || "${BACKUPCHOICE}" -gt "2" ]]; do
    read -p "Choose an option (1=Backup, 2=Restore)" BACKUPCHOICE
    case $BACKUPCHOICE in
    [1] ) 
		echo "Backup to $TAR chosen."
		if [ ! -d "${BACKUPFOLDER}" ]; then
			echo "No backup folder $BACKUPFOLDER found. Exiting."
			exit 1;
		else
			echo "Backing up folders in $BACKUPFOLDER"
		fi
		# Initialize tar command
		TARBAKCMD="tar cvpJ"
		SPLITBAKCMD="split -b 245M - ${TAR}-"
		SSLBAKCMD="openssl enc -aes256 -e -pass ${PASSWORD}"
	;;
	[2] ) 
		echo "Restore from $TAR chosen."
		if [ ! -f "${TAR}-aa" ]; then
			BACKUPCHOICE=0
			echo "No restore file found. Please re-run script and choose a valid hostname or backup location."
			exit 1;
		fi

		RESTOREFOLDER="${USERHOME}"
		read -p "Input a restore folder (Default is $RESTOREFOLDER): " NEWRESTOREFOLDER
		NEWRESTOREFOLDER=$(readlink -f "${NEWRESTOREFOLDER%/}")
		if [[ -z "$NEWRESTOREFOLDER" ]]; then
			echo "No input found. Defaulting to $RESTOREFOLDER."
		elif [ -d "$NEWRESTOREFOLDER" ]; then
			echo "Setting restore folder to ${NEWRESTOREFOLDER}"
			RESTOREFOLDER="${NEWRESTOREFOLDER}"
		fi
		
		if [ ! -d ${RESTOREFOLDER} ]; then
			echo "Restore folder ${RESTOREFOLDER} not found. Exiting."
			exit 1;
		else
			echo "Restore to ${RESTOREFOLDER}"
		fi
		
		TARRESTORECMD="tar xvpJ -C ${RESTOREFOLDER}"
		SPLITRESCMD="cat $TAR-*"
		SSLRESCMD="openssl enc -aes256 -d -pass ${PASSWORD}"
	;;
	* ) 
	echo "Please input a valid number."
	;;
    esac
done


echo "Hostname is $HOSTNAME"
echo "Backup file is $TAR"

read -p "Press any key to continue." 
echo ""

# Enable error halting.
set -eu


if [[ "$BACKUPCHOICE" -eq "1" ]]; then
	echo "Performing Backup."
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
	
	# Cache folder
	composetarcmd ".cache/banshee-1"
	composetarcmd ".cache/google-chrome"
	composetarcmd ".cache/chromium"
	composetarcmd ".cache/mozilla"
	composetarcmd ".cache/qBittorrent"
	composetarcmd ".cache/thunderbird"
	
	# Config Folder
	composetarcmd ".config/banshee-1"
	composetarcmd ".config/google-chrome"
	composetarcmd ".config/chromium"
	composetarcmd ".config/pulse"
	composetarcmd ".config/qBittorrent"
	composetarcmd ".config/syncthing"
	composetarcmd ".config/syncthing-gtk"
	composetarcmd ".config/VirtualBox"
	composetarcmd ".config/geany"
	
	# Misc
	composetarcmd ".local/share/data/ownCloud"
	composetarcmd ".areca"
	composetarcmd ".mozilla"
	composetarcmd ".thunderbird"
	composetarcmd ".ssh"
	composetarcmd ".lastpass"
	composetarcmd ".vmware"
	composetarcmd "Desktop"
	
	echo ""
	echo "Tar arguments: ${TARBAKCMD}"
	
	if [ -f "${TAR}-aa" ]; then
		echo "Removing existing backup ${TAR}."
		rm "${TAR}-"*
	fi

	${TARBAKCMD} | ${SSLBAKCMD} | ${SPLITBAKCMD}

elif [[ "$BACKUPCHOICE" -eq "2" ]]; then
	echo "Performing Restore."
	${SPLITRESCMD} | ${SSLRESCMD} | ${TARRESTORECMD} 
fi
