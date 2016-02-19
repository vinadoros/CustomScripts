#!/bin/bash

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

# Add general functions if they don't exist.
type -t grepadd >> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

ISOFOLDER="$(readlink -f $1)"
if [ ! -d "$ISOFOLDER" ]; then
	echo "Error, path $ISOFOLDER does not exist. Please specify a valid path."
	exit 1
else
	echo "Using $ISOFOLDER as iso path."
fi

set -eu

GRUBSCRIPT="/etc/grub.d/43_iso"
SEARCHFILTER="arch*.iso"

echo "Creating $GRUBSCRIPT."
bash -c "cat >$GRUBSCRIPT" <<'EOL'
#!/bin/sh
set -e
#~ set -x
EOL

bash -c "cat >>$GRUBSCRIPT" <<EOL

ISOFOLDER="$ISOFOLDER"
SEARCHFILTER="$SEARCHFILTER"

EOL

bash -c "cat >>$GRUBSCRIPT" <<'EOL'
prefix="/usr"
exec_prefix="/usr"
datarootdir="/usr/share"

. "${datarootdir}/grub/grub-mkconfig_lib"

export TEXTDOMAIN=grub
export TEXTDOMAINDIR="${datarootdir}/locale"

CLASS="--class gnu-linux --class gnu --class os"

if [ "x${GRUB_DISTRIBUTOR}" = "x" ] ; then
  OS=Linux
else
  OS="${GRUB_DISTRIBUTOR} Linux"
  CLASS="--class $(echo ${GRUB_DISTRIBUTOR} | tr 'A-Z' 'a-z' | cut -d' ' -f1|LC_ALL=C sed 's,[^[:alnum:]_],_,g') ${CLASS}"
fi

#~ # loop-AES arranges things so that /dev/loop/X can be our root device, but
#~ # the initrds that Linux uses don't like that.
case ${GRUB_DEVICE} in
  /dev/loop/*|/dev/loop[0-9])
    GRUB_DEVICE=`losetup ${GRUB_DEVICE} | sed -e "s/^[^(]*(\([^)]\+\)).*/\1/"`
  ;;
esac

for ISOFILES in "${ISOFOLDER}"/$SEARCHFILTER; do

	ISOLABEL="$(file -br "$ISOFILES" |  awk -F\' '{print $2}')"
	ISOFILENAME="$(basename "$ISOFILES")"
	ISOFILEPATH="$(dirname "$ISOFILES")"
	ISOFILESMOD="`make_system_path_relative_to_its_root "$ISOFILES"`"

	ISOHDNUM="`grub-probe --target=bios_hints "$ISOFILEPATH"`"
	ISOHDNUM="$(echo -e "${ISOHDNUM}" | sed -e 's/[[:space:]]*$//')"

	ISOHDUUID="`grub-probe --target=fs_uuid "$ISOFILEPATH"`"

	#echo "Rootsubvol: $rootsubvol"
	#echo "ISOFILES: $ISOFILES"
	#echo "ISOFILENAME: $ISOFILENAME"
	#echo "ISOFILEPATH: $ISOFILEPATH"
	#
	#echo "LINUX_ROOT_DEVICE: $LINUX_ROOT_DEVICE"
	#echo "ISOHDUUID: $ISOHDUUID"
	#echo "ISOFILESMOD: $ISOFILESMOD"

	# Boot parameters for Arch iso:
	# https://projects.archlinux.org/archiso.git/tree/docs/README.bootparams

	echo "
menuentry "$ISOFILENAME" {
	insmod part_gpt
	set isofile=\"$ISOFILESMOD\"
	loopback loop (${ISOHDNUM})\"\$isofile\"
	linux (loop)/arch/boot/x86_64/vmlinuz archisolabel=$ISOLABEL img_dev=/dev/disk/by-uuid/$ISOHDUUID img_loop=\"\$isofile\" earlymodules=loop copytoram=y
	initrd (loop)/arch/boot/x86_64/archiso.img
}
"

gettext_printf "Found iso image: %s\n" "${$ISOFILENAME}" >&2

done
EOL

chmod a+rwx "$GRUBSCRIPT"

grub_update
grub-mkconfig
