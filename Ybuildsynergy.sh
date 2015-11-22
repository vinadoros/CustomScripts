#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd >> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

# Enable binfmts if binary exists
type -p update-binfmts >> /dev/null && update-binfmts --enable

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [ "$USER" != "root" ]; then
		USERNAMEVAR=$USER
	else
		USERNAMEVAR=$(id 1000 -un)
	fi
	USERGROUP=$(id 1000 -gn)
	USERHOME=/home/$USERNAMEVAR
fi

if [[ ! -z "$1" ]]; then
	INPUTVAR="$1"
fi

cleanupfunc () {
	# Cleanup for file mode
	echo ""
	if [ ! -z "$CHPATH" ]; then
		if mount | grep -iq "$FILENAME"; then
			echo "Unmounting ${CHPATH}"
			umount -l "${CHPATH}"
		fi
		if mount | grep -iq "$FILENAME"; then
			echo "Unmounting ${CHPATH}"
			umount -f "${CHPATH}"
		fi
		sleep 1
		rm -r "${CHPATH}"
	fi
	
	exit 0
}

cleanupstart () {
	[ -z "$INSTALLFILE" ] && INSTALLFILE="$(readlink -f $INPUTVAR)"
	[ -z "$FILEPATH" ] && FILEPATH="$(dirname $INSTALLFILE)"
	if [ -f "$INPUTVAR" ]; then
		for FLD in "${FILEPATH}"/mnt-*/; do
			BASEFLD="$(basename $FLD)"
			if [ -d "$FLD" ] && mount | grep -iq "$BASEFLD"; then
				umount -l "$FLD"
			fi
			if [ -d "$FLD" ] && mount | grep -iq "$BASEFLD"; then
				umount -f "$FLD"
			fi 
			if [ -d "$FLD" ] && mount | grep -iq "$BASEFLD"; then
				echo "Cannot unmount, exiting."; 
				exit 1;
			fi
			sleep 0.1
			[ -d "$FLD" ] && rm -r "$FLD"
		done
	fi
	return 0;
}

trap cleanupfunc SIGHUP SIGINT SIGTERM

prechroot () {
	if [[ ! -d "$INPUTVAR" && ! -f "$INPUTVAR" ]]; then
		[ -z ${FILESIZE} ] && FILESIZE="8G"
		echo "Creating $INPUTVAR."
		truncate -s "${FILESIZE}" "$INPUTVAR"
		mkfs.btrfs "${INPUTVAR}"
		chmod a+rwx "${INPUTVAR}"
	fi
	
	if [ -f "$INPUTVAR" ]; then
		# Generate a random 8 character string
		RANDOMSTRING=$( date | sha1sum | fold -w6 | head -n1 )
		
		TEMPFOLDER="mnt-${RANDOMSTRING}"
		INSTALLFILE="$(readlink -f $INPUTVAR)"
		FILEPATH="$(dirname $INSTALLFILE)"
		FILENAME="$(basename $INSTALLFILE)"
		CHPATH="${FILEPATH}/${TEMPFOLDER}"
		
		mkdir -p "${CHPATH}"
		chmod a+rwx -R "${CHPATH}"
		mount "${INPUTVAR}" "${CHPATH}"
	fi

	if [ -d "$INPUTVAR" ]; then
		CHPATH="$INPUTVAR"
	fi
	
	if [ -z "$CHPATH" ]; then
		echo "Error, no file or image selected. Exiting."
		exit 1
	fi
}

sdchroot () {
	systemd-nspawn -D "${CHPATH}" --setenv=DISPLAY=$DISPLAY --setenv=QT_X11_NO_MITSHM=1 "$1"
}

bootstrapchroot () {
	export NEWHOSTNAME=Test
	export USERNAMEVAR=test
	export FULLNAME="Test"
	export SETPASS="asdf"
	export SETGRUB=1
	#~ export DEBARCH=armhf
	export DEBARCH=amd64
	export DISTRONUM=2
	if [ ! -f "${CHPATH}/etc/hostname" ]; then
		BDeb_chroot.sh "${CHPATH}"
	fi
}

cleanupstart
prechroot
bootstrapchroot

multilinereplace "${CHPATH}/build.sh" <<'EOL'
#!/bin/bash
echo "Starting build script."

rm -rf /tempfolder

apt-get install -y p7zip-full git
if [ ! -d /tempfolder ]; then
	mkdir /tempfolder
fi
cd /tempfolder

git clone https://github.com/synergy/synergy.git
cd ./synergy

# Build
apt-get install -y build-essential python lintian cmake make g++ xorg-dev libqt4-dev libcurl4-openssl-dev libavahi-compat-libdnssd-dev libssl-dev
./hm.sh conf -g1
./hm.sh build
./hm.sh package deb

echo "End build script."
rm /build.sh
EOL

sdchroot /build.sh
[ -f "${CHPATH}/build.sh" ] && rm "${CHPATH}/build.sh"

cp "${CHPATH}/tempfolder/synergy/bin/"synergy*.deb "${CHPATH}/../"
chown 1000:100 "${CHPATH}/../"synergy*.deb
chmod a+rwx "${CHPATH}/../"synergy*.deb

cleanupfunc
