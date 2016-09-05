#!/bin/bash

#Source: http://tech.karbassi.com/2009/09/29/download-all-mp3-on-a-webpage/
#Encoding: https://askubuntu.com/questions/53770/how-can-i-encode-and-decode-percent-encoded-strings-on-the-command-line
echo "Executing $0"

usage() {
cat <<EOF
Usage: $0 [Starting OC Remix number] [Ending OC Remix number]
Example: $0 3051 3102

EOF
exit 0;
}

if [ ! -z "$1" ]; then
	ocstartcount="$1"
	ocstartcount=${ocstartcount//[^0-9]/}
fi
if [ ! -z "$2" ]; then
	ocendcount="$2"
	ocendcount=${ocendcount//[^0-9]/}
fi
if [[ -z "$ocstartcount" || -z "$ocendcount" ]]; then
	echo "Error, incorrect parameters."
	usage
fi

echo "ocstartcount: $ocstartcount , ocendcount: $ocendcount"

echo ""
read -p "Press any key to download files to the current folder."

# Enable error checking
set -eu

#Variables
USERAGENT="Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_3 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8J2 Safari/6533.18.5"

occount=$ocstartcount

while [ $occount -le $ocendcount ]
do
    echo "Current URL: http://ocremix.org/remix/OCR0${occount}"
    OCURL="http://ocremix.org/remix/OCR0${occount}"

    # Skip the first URL, cycle through the other 3 (out of 4) mirrors.
    #ocmodulus=$(( ( $occount % 3 ) + 2 ))
	# Cycle through all 4 mirrors.
    ocmodulus=$(( ( $occount % 3 ) + 1 ))

	echo "Modulus: $ocmodulus"

	CURLURL=$(curl -s "${OCURL}" | grep -oie "\(http\|https\|ftp\|www\).*\.\(mp3\|wav\|m4a\|ogg\|mp4\)" | sort | uniq | sed -n "${ocmodulus}"p | head)
	echo "Download $occount from $CURLURL"

	curl -A "$USERAGENT" -sOL "$CURLURL" &

	# Wait for process to finish
	# Source: https://stackoverflow.com/questions/1058047/wait-for-any-process-to-finish
	if [[ $ocmodulus -ge 3 ]]; then
		while pgrep curl >> /dev/null; do sleep 1; done
	fi

	# Check filesize, if smaller than certain value, retry with different mirror.
	# stat --format=%s $(basename "$CURLURL")

    ((occount++))
done

echo ""
echo "Total number of tracks:" `expr $ocendcount - $ocstartcount + 1`

# Convert encoding logic
echo ""
for f in *.mp3; do
	CONVERTEDFILENAME=$(echo "$f" | sed "s@+@ @g;s@%@\\\\x@g" | xargs -0 printf "%b")
	if [ "$f" != "$CONVERTEDFILENAME" ]; then
		echo Converting "$f" to "$CONVERTEDFILENAME"
		mv "$f" "$CONVERTEDFILENAME"
	fi
done

echo -e "\nScript Completed Successfully."
