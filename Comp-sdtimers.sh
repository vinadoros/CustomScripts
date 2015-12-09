#!/bin/bash

set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

function usage()
{
cat <<EOF
Usage: sudo $0 [-r]

       -r : Remove timers
no switch : Create timers

EOF
exit 1;
}

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	usage
fi

REMOVETIMERS=0
while getopts "r" OPT
do
	case $OPT in
		h)
			usage
			;;
		r)
			echo "Removing Timers."
			REMOVETIMERS=1
			;;
		\?)
			echo "Invalid option: -$OPTARG" 1>&2
			exit 1
			;;
		:)
			;;
	esac
done
	
if [ $REMOVETIMERS = 0 ]; then
	echo "Creating timers."
elif [ $REMOVETIMERS = 1 ]; then
	echo "Removing Timers."
fi

HEADNAME="cstimer"
SDPATH="/etc/systemd/system"

set -eu

safermfld () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		RMFLD="$1"
	fi
	
	if [[ -z $(ls "$RMFLD") ]]; then 
		echo "Removing $RMFLD"
		rm -rf "$RMFLD"
	else 
		echo "$RMFLD is not empty. Not removing."
		ls -la "$RMFLD"
	fi
}

createsdtimer () {
	
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		TIMERNAME="$1"
	fi
	
	if [ -z "$2" ]; then
		echo "No parameter passed."
		return 1;
	else
		CALENDARVAR="$1"
	fi
	
	SDTIMER="$HEADNAME-$TIMERNAME.timer"
	SDSERVICE="$HEADNAME-$TIMERNAME.service"
	RUNPARTSBIN="$(which run-parts)"

	echo "Creating $SDPATH/$SDSERVICE"
	cat >"$SDPATH/$SDSERVICE" <<EOL
[Unit]
Description=Service for $TIMERNAME interval
ConditionDirectoryNotEmpty=/etc/cron.$TIMERNAME
After=network-online.target graphical.target

[Service]
Type=oneshot
IgnoreSIGPIPE=false
ExecStart=$RUNPARTSBIN /etc/cron.$TIMERNAME
EOL
	systemctl daemon-reload
	mkdir -p "/etc/cron.$TIMERNAME"

	echo "Creating $SDPATH/$SDTIMER"
	cat >"$SDPATH/$SDTIMER" <<EOL
[Unit]
Description=Timer for $TIMERNAME interval

[Timer]
OnActiveSec=30sec
Persistent=true
OnCalendar=$CALENDARVAR

[Install]
WantedBy=timers.target
EOL
	systemctl daemon-reload
	systemctl enable "$SDTIMER"
	#~ systemctl start "$SDTIMER"

}

deletesdtimer () {
	
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		TIMERNAME="$1"
	fi
	
	SDTIMER="$HEADNAME-$TIMERNAME.timer"
	SDSERVICE="$HEADNAME-$TIMERNAME.service"
	
	systemctl stop "$SDTIMER"
	systemctl disable "$SDTIMER"
	
	rm -rf "$SDPATH/$SDTIMER" "$SDPATH/$SDSERVICE"
	safermfld "/etc/cron.$TIMERNAME"
}

if [ $REMOVETIMERS = 0 ]; then
	createsdtimer "hourly" "hourly"
	createsdtimer "daily" "daily"
	createsdtimer "weekly" "weekly"
elif [ $REMOVETIMERS = 1 ]; then
	deletesdtimer "hourly"
	deletesdtimer "daily"
	deletesdtimer "weekly"
fi
