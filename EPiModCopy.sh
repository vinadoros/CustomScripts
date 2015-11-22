#!/bin/bash

set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Stash locations
STASHMODULES="/media/Box/RPi/modules.tar.gz"
STASHKERNEL="/media/Box/RPi/kernel_custom.img"

if [ ! -f $STASHMODULES ]; then
	echo "Error, $STASHMODULES not found, exiting."
	exit 1;
fi

# Strip trailing slash if it exists.
INSTALLPATH=${1%/}
# Get real link (extract symlink if it exists)
LIBPATH=$(readlink -f "${INSTALLPATH}/lib")

# Remove existing modules
EXISTINGMODULES="$(find "${LIBPATH}/modules" -maxdepth 1 -type d -name '*RMKCUSTOM*' | head -n1)"
if [ -d "${EXISTINGMODULES}" ]; then
	echo "Deleting existing modules: ${EXISTINGMODULES}."
	rm -rf "${EXISTINGMODULES}"
fi

echo "Extracting modules to ${LIBPATH}."
tar -C "${LIBPATH}/" -pxvf "${STASHMODULES}"

echo "Copying kernel to ${INSTALLPATH}."
cp -f "${STASHKERNEL}" "${INSTALLPATH}/"

echo "Script completed successfully."
