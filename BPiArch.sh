#!/bin/bash

# Halt on any error.
set -e

###############################################################################
##################        Initial Setup and Variables      ####################
###############################################################################

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

if [[ ! $(type -P update-binfmts) || ! $(type -P qemu-arm-static) ]]; then
	echo "No qemu-arm-static or update-binfmts binaries found. Exiting."
	exit 1;
fi

URL="http://archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz"
TARIMG=$(basename ${URL}) # Just the file name

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

export SETGRUB=1
export NEWHOSTNAME="raspberrypi"
source "$SCRIPTDIR/F-ChrootInitVars.sh"

# Strip trailing slash if it exists.
INSTALLPATH=${1%/}
if [ -z "${INSTALLPATH}" ]; then
	echo "No install path or file found. Exiting."
	exit 1;
else
	echo "Installpath is ${INSTALLPATH}."
fi

#Path above installpath
TOPPATH=${INSTALLPATH}/..

read -p "Press any key to continue."

# Check install path
if [ ! -d ${INSTALLPATH} ]; then
	echo "${INSTALLPATH} doesn't exist. Exiting."
	exit 1;
fi

chmod a+rwx "${INSTALLPATH}"

if [ ! -f ${INSTALLPATH}/etc/hostname ]; then
	if [ ! -f ${TOPPATH}/${TARIMG} ]; then
		echo "Retrieving image."
		wget -P ${TOPPATH}/ ${URL}
		chmod a+rwx ${TOPPATH}/${TARIMG}
	fi
	echo "Decompressing ${TARIMG} to ${INSTALLPATH}."
	#~ tar --same-owner --numeric-owner -pxvf ${TOPPATH}/${TARIMG} -C ${INSTALLPATH}
	bsdtar -vxpf "${TOPPATH}/${TARIMG}" -C "${INSTALLPATH}"
	sync

	echo "${NEWHOSTNAME}" > "${INSTALLPATH}/etc/hostname"
	sed -i 's/\(127.0.0.1\tlocalhost.localdomain\tlocalhost\)\(.*\)/\1 '$NEWHOSTNAME'/g' "${INSTALLPATH}/etc/hosts"
	echo "LANG=en_US.UTF-8" > "${INSTALLPATH}/etc/locale.conf"
	sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' "${INSTALLPATH}/etc/locale.gen"
else
	echo "${INSTALLPATH} not empty. Skipping extraction."
fi

if [[ -L ${INSTALLPATH}/etc/resolv.conf ]]; then
	# Remove resolv.conf and replace with symlink.
	echo "Removing resolv.conf symlink."
	rm -f ${INSTALLPATH}/etc/resolv.conf
fi

# Create main part of setup script for chroot.
bash -c "cat >>${SETUPSCRIPT}" <<'EOLXYZ'

sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen

echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG=en_US.UTF-8
if [ -f /etc/localtime ]; then
	rm /etc/localtime
fi
if [ ! -f /etc/localtime ]; then
	ln -s /usr/share/zoneinfo/America/New_York /etc/localtime
fi

# Delete existing user 1000 if exists.
set +eu
USER1000="$(id -un 1000)"
if [[ ! -z "$USER1000" && "$USER1000" != "$USERNAMEVAR" ]]; then
	echo "Deleting existing user $USER1000"
	userdel -f "$USER1000"
fi

if [ -z "$SETPASS" ]; then
	echo "Enter a root password."
	until passwd
		do echo "Try again in 2 seconds."
		sleep 2
		echo "Enter a root password."
	done
else
	echo "Changing password for root automatically."
	echo "root:$SETPASS" | chpasswd
fi

if ! grep -i $USERNAMEVAR /etc/passwd; then
	useradd -m -g users -G wheel -s /bin/bash $USERNAMEVAR
	if [ -z "$SETPASS" ]; then
		echo "Enter a password for $USERNAMEVAR."
		until passwd $USERNAMEVAR
			do echo "Try again in 2 seconds."
			sleep 2
			echo "Enter a root password."
		done
	else
		echo "Changing password for $USERNAMEVAR automatically."
		echo "$USERNAMEVAR:$SETPASS" | chpasswd
	fi
	chfn -f "$FULLNAME" $USERNAMEVAR
fi

pacman -Syu --noconfirm
pacman -S --needed --noconfirm base-devel rsync

# Enable sudo for wheel group.
if grep -iq "# %wheel ALL=(ALL) ALL" /etc/sudoers; then
	sed -i.w 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
fi
visudo -c
if [ -f /etc/sudoers.w ]; then
	rm /etc/sudoers.w
fi

# Rpi headers
pacman -S --needed --noconfirm linux-raspberrypi-headers

# Install avahi
pacman -S --needed --noconfirm avahi nss-mdns
systemctl enable avahi-daemon.service

#Install xorg
pacman -S --needed --noconfirm xorg-server xorg-server-utils mesa-libgl xorg-xinit xterm mesa xf86-video-fbdev

#Network manager
pacman -S --needed --noconfirm wget networkmanager dhclient ntfs-3g gptfdisk dosfstools btrfs-progs xfsprogs f2fs-tools openssh
systemctl enable NetworkManager
systemctl enable sshd

pacman -S --needed --noconfirm git
git clone "https://github.com/vinadoros/CustomScripts.git" "/opt/CustomScripts"
chmod a+rwx "/opt/CustomScripts"

EOLXYZ

chmod a+rwx ${INSTALLPATH}/setupscript.sh

cp -f /usr/bin/qemu-arm-static ${INSTALLPATH}/usr/bin
update-binfmts --enable

set +e
# Run script in chroot
${SNCHROOTCMD} /setupscript.sh
set -e

# Delete script when done.
rm "${SETUPSCRIPT}"
rm "${GRUBSCRIPT}"

echo "Script finished successfully."
