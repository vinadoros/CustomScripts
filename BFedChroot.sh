#!/bin/bash

# Halt on any error.
set -e

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

###############################################################################
##################        Initial Setup and Variables      ####################
###############################################################################

#Temporary Mount
TMPMNT=fedora_temp_mount

CENTOSURL="http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.raw.tar.gz"
FEDURL="https://download.fedoraproject.org/pub/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-23-20151030.x86_64.raw.xz"

fedoraimgvars () {
	COMPRESSEDIMG=$(basename ${URL}) # Just the file name
	IMG=${COMPRESSEDIMG:0:-3}        # Pull .xz off of the end
}

centosimgvars () {
	COMPRESSEDIMG=$(basename ${URL}) # Just the file name
	IMG=${COMPRESSEDIMG:0:-7}        # Pull .tar.gz off of the end
}

decompressimg () {
	if [[ "$FEDREL" = 1 ]]; then
		echo "Decompressing fedora image."
		xz -dkv "${PATHOFCOMPRESSEDIMG}"
		chmod a+rwx "${PATHOFIMG}"
	elif [[ "$FEDREL" = 2 ]]; then
		echo "Decompressing centos image."
		tar -xvpf "$PATHOFCOMPRESSEDIMG" -C "${INSTALLPATH}/"
		# Rename the extracted image to the image generated above.
		BEGINIMG=${COMPRESSEDIMG:0:8}
		mv "${INSTALLPATH}/$BEGINIMG"*.raw "$PATHOFIMG"
	fi
}

if [ -z "$FEDREL" ]; then
	read -p "Input a Release (1=Fedora, 2=CentOS): " FEDREL
	USERNAMEVAR=${USERNAMEVAR//[^0-9_]/}
	if [ -z "$FEDREL" ]; then
		echo "Defaulting to 1."
		FEDREL=1
	fi
	if [[ "$FEDREL" = 1 ]]; then
		echo "Input is 1. Using Fedora."
		URL="$FEDURL"
		fedoraimgvars
	elif [[ "$FEDREL" = 2 ]]; then
		echo "Input is 2. Using CentOS."
		URL="$CENTOSURL"
		centosimgvars
	else
		echo "Error, invalid input of $FEDREL. Exiting."
		exit 1;
	fi
fi
echo "You entered" $FEDREL

source "$SCRIPTDIR/F-ChrootInitVars.sh"

#Path above installpath
TOPPATH=${INSTALLPATH}/..
PATHOFCOMPRESSEDIMG="${INSTALLPATH}/${COMPRESSEDIMG}"
PATHOFIMG="${INSTALLPATH}/${IMG}"
PATHOFTOPMNT="${TOPPATH}/${TMPMNT}"

read -p "Press any key to continue." 

if [ ! -f "${INSTALLPATH}/etc/hostname" ]; then
	if [ ! -f "${PATHOFCOMPRESSEDIMG}" ]; then
		echo "Retrieving compressed image."
		wget -P "${INSTALLPATH}/" "${URL}"
		chmod a+rwx "${PATHOFCOMPRESSEDIMG}"
	fi
	if [ ! -f "${PATHOFIMG}" ]; then
		decompressimg
	fi
	# Find the starting byte and the total bytes in the 1st partition
	# NOTE: normally would be able to use partx/kpartx directly to loopmount
	#       the disk image and add the partitions, but inside of docker I found
	#       that wasn't working quite right so I resorted to this manual approach.
	PAIRS=$(partx --pairs ${PATHOFIMG})
	eval `echo "$PAIRS" | head -n 1 | sed 's/ /\n/g'`
	STARTBYTES=$((512*START))   # 512 bytes * the number of the start sector
	TOTALBYTES=$((512*SECTORS)) # 512 bytes * the number of sectors in the partition
	
	# Discover the next available loopback device
	LOOPDEV=$(losetup -f)
	
	# Loopmount the first partition of the device
	losetup -v --offset $STARTBYTES --sizelimit $TOTALBYTES $LOOPDEV "${PATHOFIMG}"
		
	# Mount it on $TMPMNT
	if [ ! -d "${PATHOFTOPMNT}" ]; then
		mkdir -p "${PATHOFTOPMNT}"
		chmod a+rwx "${PATHOFTOPMNT}"
	fi
	mount $LOOPDEV "${PATHOFTOPMNT}"
	
	# Copy all files
	echo "Copying files into chroot folder."
	sudo rsync -axHAWX --info=progress2 --numeric-ids --del --filter="protect $IMG" --filter="protect $COMPRESSEDIMG" --filter="protect /*.sh" "${PATHOFTOPMNT}/" "${INSTALLPATH}/"
	if [ -f "${INSTALLPATH}/etc/hostname" ]; then
		rm "${INSTALLPATH}/etc/hostname"
	fi
	
	# Unmount and clean up loop mount
	umount -l "${PATHOFTOPMNT}"
	while mount | grep "$LOOPDEV"; do
		umount -l "$LOOPDEV" || true
		sleep 2
	done
	if [ -b $LOOPDEV ]; then
		losetup -d $LOOPDEV
	fi
	rm -rf "${PATHOFTOPMNT}/"
	rm "${PATHOFIMG}"
	rm "${PATHOFCOMPRESSEDIMG}"
	
	chmod a+rwx "${INSTALLPATH}/"
	
	# Generate fstab
	# || : forces error code of genfstab to be 0 if it fails, like if the path isn't a mount point.
	genfstab -Up ${INSTALLPATH} > ${INSTALLPATH}/etc/fstab || : 
	
	echo ${NEWHOSTNAME} > "${INSTALLPATH}/etc/hostname"
	#sed -i 's/\(127.0.0.1\tlocalhost\)\(.*\)/\1 '${NEWHOSTNAME}'/g' ${INSTALLPATH}/etc/hosts
else
	echo "${INSTALLPATH} not empty. Skipping fedora download."
fi

# Add to initial portion of script for chroot.
bash -c "cat >>${SETUPSCRIPT}" <<EOLXYZ
FEDREL=$FEDREL
EOLXYZ

# Create main part of setup script for chroot.
bash -c "cat >>${SETUPSCRIPT}" <<'EOLXYZ'

if [[ $FEDREL = 1 ]]; then
	INSTCMD=dnf
elif [[ $FEDREL = 2 ]]; then
	INSTCMD=yum
fi

$INSTCMD update -y
$INSTCMD install -y nano sudo

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

if ! grep -i ${USERNAMEVAR} /etc/passwd; then
	adduser ${USERNAMEVAR}
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
	usermod -aG daemon,bin,sys,adm,tty,disk,lp,mail,man,kmem,dialout,cdrom,floppy,tape,wheel,audio,utmp,video,games,users,systemd-journal ${USERNAMEVAR}
	chfn -f "${FULLNAME}" ${USERNAMEVAR}
fi

if [[ $FEDREL = 1 ]]; then
	rpm --quiet --query folkswithhats-release || $INSTCMD -y --nogpgcheck install http://folkswithhats.org/repo/$(rpm -E %fedora)/RPMS/noarch/folkswithhats-release-1.0.1-1.fc$(rpm -E %fedora).noarch.rpm
	rpm --quiet --query rpmfusion-free-release || $INSTCMD -y --nogpgcheck install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
	rpm --quiet --query rpmfusion-nonfree-release || $INSTCMD -y --nogpgcheck install http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
	$INSTCMD -y --nogpgcheck install fedy

	$INSTCMD install -y freetype-freeworld
fi

$INSTCMD groupinstall -y "Basic Desktop"
$INSTCMD install -y yumex

systemctl disable cloud-config.service cloud-final.service cloud-init.service cloud-init-local.service

EOLXYZ
chmod a+rwx "${SETUPSCRIPT}"

# Run script in chroot
${SNCHROOTCMD} /setupscript.sh

# Delete script when done.
rm "${SETUPSCRIPT}"

# Copy wifi connections to guest
echo "Copying network manager connections to install folder."
cp -aRvn /etc/NetworkManager/system-connections/ "${INSTALLPATH}/etc/NetworkManager/"
for file in "${INSTALLPATH}"/etc/NetworkManager/system-connections/*; do
	if ! ( echo "$file" | grep -iq "etc/NetworkManager/system-connections/*" ); then
		sed -i 's/permissions=.*$/permissions=/g' "$file"
		sed -i 's/mac-address=.*$/mac-address=/g' "$file"
	fi
done

# Add to initial portion of script for chroot.
bash -c "cat >>${GRUBSCRIPT}" <<EOLXYZ
FEDREL=$FEDREL
EOLXYZ

# Create main part of grub script for chroot.
bash -c "cat >>${GRUBSCRIPT}" <<'EOLXYZ'

if [[ $FEDREL = 1 ]]; then
	INSTCMD=dnf
elif [[ $FEDREL = 2 ]]; then
	INSTCMD=yum
fi

export PATH=$PATH:/bin:/usr/local/sbin:/usr/sbin:/sbin

case $SETGRUB in
[1]) 
	echo "Not installing kernel."
	;;
[2-4])
	echo "Installing kernel."
	$INSTCMD install -y kernel linux-firmware
	$INSTCMD install -y grub2 grubby efibootmgr efivar
	grub2-mkconfig -o /boot/grub/grub.cfg
	;;
	
esac
    
case $SETGRUB in

[1]* ) 
	echo "You asked to do nothing. Be sure to install a bootloader."
	;;

[2]* ) 
	echo "You asked to perform 'grub-isntall $DEVPART'."
	grub2-install --target=i386-pc --recheck --debug $DEVPART
	;;

[3]* ) 
	echo "You asked to install efi bootloader."
	while ! mount | grep -iq "/boot/efi"; do
		echo "/boot/efi is not mounted. Please mount it."
		read -p "Press any key to continue."
	done
	
	grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Fedora --recheck --debug

	;;

[4]* ) 
	if [ ! -z $PART ]; then
		echo "Installing grub to $PART."
		grub2-install --target=i386-pc --recheck --debug $PART
	else
		echo "No partition variable specified. Not installing grub."
	fi
	;;

esac

echo "End grubscript.sh"

EOLXYZ

set +e
# Run script in chroot
${ACCHROOTCMD} /grubscript.sh
set -e

# Delete script when done.
rm ${GRUBSCRIPT}

echo "Script finished successfully."
