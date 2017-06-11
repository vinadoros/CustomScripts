#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add standard docker containers
docker run -d --name portainer --restart=always -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer
