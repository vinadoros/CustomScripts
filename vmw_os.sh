#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

if type zypper; then
  zypper in -yl kernel-devel
fi

SOURCEMODFOLDER="/usr/lib/vmware/modules/source"
TEMPFOLDER="/var/tmp/vmwaresource"
mkdir -p "$TEMPFOLDER"
cp $SOURCEMODFOLDER/* $TEMPFOLDER/

cd $TEMPFOLDER/
for file in $TEMPFOLDER/*.tar; do
  tar -xvf $file
done

chmod a+rwx -R $TEMPFOLDER/

# Make vmmon
cd $TEMPFOLDER/vmmon-only
echo -e "\n\nCompiling vmmon\n"
make
cp $TEMPFOLDER/vmmon.o /lib/modules/`uname -r`/kernel/drivers/misc/vmmon.ko

# Make vmnet
cd $TEMPFOLDER/vmnet-only
echo -e "\n\nCompiling vmnet\n"
make
cp $TEMPFOLDER/vmnet.o /lib/modules/`uname -r`/kernel/drivers/misc/vmnet.ko

# Force detect modules and restart vmware service.
cd $HOME
depmod -a
/etc/init.d/vmware restart
rm -rf "$TEMPFOLDER"
