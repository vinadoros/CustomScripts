#!/usr/bin/env bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Install docker items
$SCRIPTDIR/Comp-Docker.sh

# Install docker-compose
mkdir -p /opt/bin
curl -L https://github.com/docker/compose/releases/download/1.14.0/docker-compose-`uname -s`-`uname -m` > /opt/bin/docker-compose
chmod a+x /opt/bin/docker-compose
