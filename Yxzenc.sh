#!/bin/bash

usage () {
	echo -e "\nUsage:"
	echo "-h - Help."
	echo "-d - Decrypt file."
	echo "-e - Encrypt file."
	exit 0;
}

setxzopts () {
	MACHINEARCH=$(uname -m)
	if [ "${MACHINEARCH}" = "armv7l" ]; then
		export XZ_OPT=-1
	else
		export XZ_OPT=-T0
	fi
}

xzfile () {
	xz -v -z "$ENCFILE" || true
}

unxzfile () {
	xz -v -d "$DECFILEPATH/$DECXZFILE" || true
}

sslfile () {
	openssl enc -aes256 -e -in "$ENCFILEPATH/$ENCXZFILE" -out "$ENCFILEPATH/$ENCSSLFILE"
	rm "$ENCFILEPATH/$ENCXZFILE"
}

unsslfile () {
	openssl enc -aes256 -d -in "$DECFILEPATH/$DECFILEBASE" -out "$DECFILEPATH/$DECXZFILE"
	rm "$DECFILEPATH/$DECFILEBASE"
}

# Get options
while getopts "he:d:" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		e)
			ENCFILE="$OPTARG"
			if [ -f "$ENCFILE" ]; then
				ENCFILE="$(readlink -f "$ENCFILE")"
				ENCFILEPATH="$(dirname "$ENCFILE")"
				ENCFILEBASE="$(basename "$ENCFILE")"
				# Set filename with xz extension
				ENCXZFILE="${ENCFILEBASE}.xz"
				# Set filename with ssl extension
				ENCSSLFILE="${ENCXZFILE}.ssl"
			else
				echo "Error, $ENCFILE is not a file. Exiting."
				usage
			fi
			;;
		d)
			DECFILE="$OPTARG"
			if [ -f "$DECFILE" ]; then
				DECFILE="$(readlink -f "$DECFILE")"
				DECFILEPATH="$(dirname "$DECFILE")"
				DECFILEBASE="$(basename "$DECFILE")"
				# Get filename without extension
				DECXZFILE="${DECFILEBASE%.*}"
				# Get extension
				DECFILEEXT="${DECFILEBASE##*.}"
				if [ "$DECFILEEXT" != "ssl" ]; then
					echo "Error, $DECFILEBASE is not an ssl file. Exiting."
					usage
				fi
			else
				echo "Error, $DECFILE is not a file. Exiting."
				usage
			fi
			;;
		\?)
			echo "Invalid option: -$OPTARG" 1>&2
			usage
			;;
		:)
			echo "Option -$OPTARG requires an argument" 1>&2
			usage
			;;
	esac
done

set -e

setxzopts

if [[ ! -z $DECFILE && ! -z $ENCFILE ]] || [[ -z $DECFILE && -z $ENCFILE ]]; then
	echo "Select either encryption or decryption. Exiting."
	usage
fi

if [ -f "$DECFILE" ]; then
	echo "Decrypting $DECFILE."
	unsslfile
	unxzfile
fi

if [ -f "$ENCFILE" ]; then
	echo "Encrypting $ENCFILE."
	xzfile
	sslfile
fi

echo "Script Completed Successfully."
