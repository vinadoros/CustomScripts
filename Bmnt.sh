#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

echo "Executing Bmnt.sh"

# Generate a random 8 character string
RANDOMSTRING=$( date | sha1sum | fold -w6 | head -n1 )

TEMPFOLDER="mnt-${RANDOMSTRING}"
INSTALLFILE="$(readlink -f ${1})"
FILEPATH="$(dirname $INSTALLFILE)"
FILENAME="$(basename $INSTALLFILE)"
INSTALLPATH="${FILEPATH}/${TEMPFOLDER}"
FILESIZE="${2}"

cleanupfunc () {
	# Cleanup for file mode
	echo ""
	if mount | grep -iq "$FILENAME"; then
		echo "Unmounting ${INSTALLPATH}"
		umount -l "${INSTALLPATH}"
	fi
	if mount | grep -iq "$FILENAME"; then
		echo "Unmounting ${INSTALLPATH}"
		umount -f "${INSTALLPATH}"
	fi
	sleep 1
	rm -r "${INSTALLPATH}"
	exit 0
}

trap cleanupfunc SIGHUP SIGINT SIGTERM

# Cleanup for file mode
if [ -d ${INSTALLPATH} ]; then
	echo "Unmounting and deleting ${INSTALLPATH}"
	read -p "Press any key to delete." 
	cleanupfunc
	exit 1;
fi

# Do file stuff if $1 is f
if [ -z "${INSTALLFILE}" ]; then
	echo "No install file specified. Exiting."
	exit 1;
else
	echo "Installfile is ${INSTALLFILE}."
	echo "Installpath is ${INSTALLPATH}."
fi
if [ ! -f ${INSTALLFILE} ]; then
	[ -z ${FILESIZE} ] && FILESIZE="8G"
	echo "Creating ${INSTALLFILE}."
	truncate -s "${FILESIZE}" "${INSTALLFILE}"
	mkfs.btrfs "${INSTALLFILE}"
	chmod a+rwx "${INSTALLFILE}"
	#Disable copy-on-write for new file.
	chattr +C "${INSTALLFILE}"
fi
if [ ! -d ${INSTALLPATH} ]; then
	echo "Creating temporary folder ${INSTALLPATH}"
	mkdir -p "${INSTALLPATH}"
	chmod a+rwx -R "${INSTALLPATH}"
fi

mount "${INSTALLFILE}" "${INSTALLPATH}"

read -p "Press any key to unmount temp filesystem." 

cleanupfunc
