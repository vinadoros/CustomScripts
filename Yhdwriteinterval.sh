#!/bin/bash

function usage()
{
cat <<EOF
Usage: sudo $0 [PATH TO ROOT OF DRIVE]

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
	echo "Using ${HDPATH} as path."
fi

set -eu

getvars() {
	BASEPATH="$(basename $HDPATH)"
	# Remove spaces from basepath.
	BASEPATH="${BASEPATH//[[:blank:]]/}"
	
	# Get mount device in /dev
	#DEVDRIVE="$(mount | grep "${HDPATH}" | awk -F" " '{ print $1 }')"
	
	# Get systemd mount name.
	SYSTEMDMNT="$(systemctl | grep "${HDPATH}" | awk -F" " '{ print $1 }')"	
	
	HDSCRIPT="/usr/local/bin/hdalive-${BASEPATH}.sh"
	SDPATH="/etc/systemd/system"
	SDSERVICE="hdalive-${BASEPATH}.service"
	SDTIMER="hdalive-${BASEPATH}.timer"
}

getvars

echo "Script path: $HDSCRIPT"
echo "Device service: $SYSTEMDMNT"
echo "Systemd Service: $SDPATH/$SDSERVICE"
echo "Systemd timer: $SDPATH/$SDTIMER"
echo ""
read -p "Press any key to create script."


echo "Creating $HDSCRIPT"
cat >"$HDSCRIPT" <<EOL
#!/bin/bash

HDPATH="$HDPATH"
HDTESTFILE="\$HDPATH/testfile.txt"

getmountstatus () {
	HDSTATUS="\$(systemctl is-active \$HDPATH)"
	#echo \$HDSTATUS
}

rmtestfile () {
	if [ -f "\$HDTESTFILE" ]; then
		echo "Removing file \$HDTESTFILE."
		rm -f "\$HDTESTFILE"
	fi
	sync
}

writetestfile () {
	echo "Writing \$HDTESTFILE."
	touch "\$HDTESTFILE"
	dd if=/dev/urandom of="\$HDTESTFILE" bs=1M count=10 &> /dev/null
	sync
}

hdalive () {
	getmountstatus
	if [ "\$HDSTATUS" = "active" ]; then
		rmtestfile
		writetestfile
		rmtestfile
		exit 0;
	else
		echo "Hard drive \$HDPATH not mounted. Exiting."
		exit 1
	fi
}

trap rmtestfile SIGHUP SIGINT SIGTERM

hdalive

EOL
chmod a+rwx "$HDSCRIPT"

echo "Creating $SDPATH/$SDSERVICE"
cat >"$SDPATH/$SDSERVICE" <<EOL
[Unit]
Description=Write to $BASEPATH drive periodically
#Requires=$SYSTEMDMNT
After=$SYSTEMDMNT

[Service]
Type=simple
ExecStart=$HDSCRIPT
#Restart=on-failure
EOL
systemctl daemon-reload

echo "Creating $SDPATH/$SDTIMER"
cat >"$SDPATH/$SDTIMER" <<EOL
[Unit]
Description=Timer for $SDSERVICE

[Timer]
OnActiveSec=1min
OnUnitActiveSec=5min 

[Install]
WantedBy=timers.target
EOL
systemctl daemon-reload
systemctl enable "$SDTIMER"
systemctl start "$SDTIMER"

echo "Use \"systemctl list-timers\" to view timer information."
