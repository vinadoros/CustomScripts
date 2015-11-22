#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Halt on any error.
set -eu

INSTALLPATH=$1
if [ -z "${INSTALLPATH}" ]; then
	INSTALLPATH=.
	echo "No install path found. Defaulting to ${INSTALLPATH}."
else
	echo "Installpath is ${INSTALLPATH}."
fi

SETUPSCRIPT="${INSTALLPATH}/setupscript.sh"
echo "Script is ${SETUPSCRIPT}."

if [ -f ${SETUPSCRIPT} ]; then
	echo "Removing existing script at ${SETUPSCRIPT}."
	rm -f ${SETUPSCRIPT}
fi
