#!/bin/bash

# Halt on any error.
set -e

###############################################################################
##################        Initial Setup and Variables      ####################
###############################################################################

#Temporary Mount
TMPMNT=fedora_temp_mount

URL="https://download.fedoraproject.org/pub/fedora/linux/releases/23/Cloud/x86_64/Images/Fedora-Cloud-Base-23-20151030.x86_64.raw.xz"
XZIMG=$(basename ${URL}) # Just the file name
IMG=${XZIMG:0:-3}        # Pull .xz off of the end

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

source "$SCRIPTDIR/F-ChrootInitVars.sh"

#Path above installpath
TOPPATH=${INSTALLPATH}/..

# Chroot command
CHROOTCMD="systemd-nspawn -D ${INSTALLPATH}"

read -p "Press any key to continue." 

if [ ! -f ${INSTALLPATH}/etc/hostname ]; then
	if [ ! -f ${INSTALLPATH}/${XZIMG} ]; then
		echo "Retrieving Fedora xz image."
		wget -P ${INSTALLPATH}/ ${URL}
		chmod a+rwx ${INSTALLPATH}/${XZIMG}
	fi
	if [ ! -f ${INSTALLPATH}/${IMG} ]; then
		echo "Decompressing xz image."
		xz -d -k ${INSTALLPATH}/${XZIMG}
		chmod a+rwx ${INSTALLPATH}/${IMG}
	fi
	# Find the starting byte and the total bytes in the 1st partition
	# NOTE: normally would be able to use partx/kpartx directly to loopmount
	#       the disk image and add the partitions, but inside of docker I found
	#       that wasn't working quite right so I resorted to this manual approach.
	PAIRS=$(partx --pairs ${TOPPATH}/${IMG})
	eval `echo "$PAIRS" | head -n 1 | sed 's/ /\n/g'`
	STARTBYTES=$((512*START))   # 512 bytes * the number of the start sector
	TOTALBYTES=$((512*SECTORS)) # 512 bytes * the number of sectors in the partition
	
	# Discover the next available loopback device
	LOOPDEV=$(losetup -f)
	
	# Loopmount the first partition of the device
	losetup -v --offset $STARTBYTES --sizelimit $TOTALBYTES $LOOPDEV ${TOPPATH}/${IMG}
		
	# Mount it on $TMPMNT
	if [ ! -d ${TOPPATH}/${TMPMNT} ]; then
		mkdir -p ${TOPPATH}/${TMPMNT}
		chmod a+rwx ${TOPPATH}/${TMPMNT}
	fi
	mount $LOOPDEV ${TOPPATH}/${TMPMNT}
	
	# Copy all files
	echo "Copying files into chroot folder."
	sudo rsync -axHAWX --info=progress2 --numeric-ids --del ${TOPPATH}/${TMPMNT}/ ${INSTALLPATH}/
	
	# Unmount and clean up loop mount
	umount ${TOPPATH}/$TMPMNT
	losetup -d $LOOPDEV
	rm -rf ${TOPPATH}/${TMPMNT}/
	rm ${INSTALLPATH}/${IMG}
	
	chmod a+rwx ${INSTALLPATH}/
	
	echo ${NEWHOSTNAME} > ${INSTALLPATH}/etc/hostname
	#sed -i 's/\(127.0.0.1\tlocalhost\)\(.*\)/\1 '${NEWHOSTNAME}'/g' ${INSTALLPATH}/etc/hosts
else
	echo "${INSTALLPATH} not empty. Skipping fedora download."
fi

if [ -f ${INSTALLPATH}/setupscript.sh ]; then
	echo "Removing existing setupscript.sh."
	rm ${INSTALLPATH}/setupscript.sh
fi

# Create initial portion of script for chroot.
bash -c "cat >>${INSTALLPATH}/setupscript.sh" <<EOLXYZ
#!/bin/bash

# Carry-over variables
USERNAMEVAR=${USERNAMEVAR}
NEWHOSTNAME=${NEWHOSTNAME}
FULLNAME="${FULLNAME}"
VBOXGUEST=${VBOXGUEST}
QEMUGUEST=${QEMUGUEST}
VMWGUEST=${VMWGUEST}

EOLXYZ

# Create main part of setup script for chroot.
bash -c "cat >>${INSTALLPATH}/setupscript.sh" <<'EOLXYZ'

dnf update -y
dnf install -y nano sudo

echo "Enter a root password."
until passwd
	do echo "Try again in 2 seconds."
	sleep 2
	echo "Enter a root password."
done

if ! grep -i ${USERNAMEVAR} /etc/passwd; then
	adduser ${USERNAMEVAR}
	usermod -aG daemon,bin,sys,adm,tty,disk,lp,mail,man,kmem,dialout,cdrom,floppy,tape,wheel,audio,utmp,video,games,users ${USERNAMEVAR}
	chfn -f "${FULLNAME}" ${USERNAMEVAR}
	until passwd ${USERNAMEVAR}
		do echo "Try again in 2 seconds."
		sleep 2
		echo "Enter a password for ${USERNAMEVAR}."
	done
fi

rpm --quiet --query ozon-repos || dnf -y --nogpgcheck install http://goodies.ozon-os.com/repo/$(rpm -E %fedora)/noarch/ozon-repos-$(rpm -E %fedora)-5$(rpm -E %dist).noarch.rpm
rpm --quiet --query rpmfusion-free-release || dnf -y --nogpgcheck install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
rpm --quiet --query rpmfusion-nonfree-release || dnf -y --nogpgcheck install http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf install -y freetype-freeworld
dnf groupinstall -y "Basic Desktop"
dnf install -y yumex

systemctl disable cloud-config.service cloud-final.service cloud-init.service cloud-init-local.service

EOLXYZ
chmod a+rwx ${INSTALLPATH}/setupscript.sh

# Run script in chroot
${CHROOTCMD} /setupscript.sh

# Delete script when done.
rm ${INSTALLPATH}/setupscript.sh

# Copy wifi connections to guest
echo "Copying network manager connections to install folder."
cp -aRvn /etc/NetworkManager/system-connections/ "${INSTALLPATH}/etc/NetworkManager/"
for file in "${INSTALLPATH}"/etc/NetworkManager/system-connections/*; do
	if ! ( echo "$file" | grep -iq "etc/NetworkManager/system-connections/*" ); then
		sed -i 's/permissions=.*$/permissions=/g' "$file"
		sed -i 's/mac-address=.*$/mac-address=/g' "$file"
	fi
done

# Create main part of grub script for chroot.
bash -c "cat >>${GRUBSCRIPT}" <<'EOLXYZ'
export PATH=$PATH:/bin:/usr/local/sbin:/usr/sbin:/sbin

case $SETGRUB in
[1]) 
	echo "Not installing kernel."
	;;
[2-4])
	echo "Installing kernel."
	
	# Liquorix repo
	if [[ "$DEBARCH" = "amd64" || "$DEBARCH" = "i386" ]] && ! grep -iq "liquorix.net" /etc/apt/sources.list; then
		echo "Installing liquorix kernel."
		add-apt-repository "deb http://liquorix.net/debian sid main past"
		apt-get update
		apt-get install -y --force-yes liquorix-keyring
		apt-get update
	fi
	
	# Install kernels.
	[ "${DEBARCH}" = "amd64" ] && apt-get install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64
	[ "${DEBARCH}" = "i386" ] && apt-get install -y linux-image-liquorix-686-pae linux-headers-liquorix-686-pae
	# Remove stock kernels if installed.
	dpkg-query -l | grep -iq "linux-image-amd64" && apt-get --purge remove -y linux-image-amd64
	dpkg-query -l | grep -iq "linux-image-686-pae" && apt-get --purge remove -y linux-image-686-pae
	dpkg-query -l | grep -iq "linux-headers-generic" && apt-get --purge remove -y linux-headers-generic
	
	if [[ "$DISTRONUM" -eq "1" || "$DISTRONUM" -eq "2" ]]; then
<<COMMENT2
		if [[ "$DEBARCH" = "amd64" ]]; then
			apt-get install -y linux-image-amd64
		fi
		if [[ "$DEBARCH" = "i386" || "$DEBARCH" = "i686" ]]; then
			apt-get install -y linux-image-686-pae
		fi
COMMENT2
		apt-get install -y firmware-linux gfxboot
		echo "firmware-ipw2x00 firmware-ipw2x00/license/accepted boolean true" | debconf-set-selections
		echo "firmware-ivtv firmware-ivtv/license/accepted boolean true" | debconf-set-selections
		DEBIAN_FRONTEND=noninteractive apt-get install -y ^firmware-* 
	fi
	
	if [[ "$DISTRONUM" -eq "3" ]]; then
		#apt-get install -y linux-image-generic linux-headers-generic
		apt-get install -y gfxboot gfxboot-theme-ubuntu linux-firmware
	fi
	;;
	
esac
    
case $SETGRUB in

[1]* ) 
	echo "You asked to do nothing. Be sure to install a bootloader."
	;;

[2]* ) 
	echo "You asked to perform 'grub-isntall $DEVPART'."
	DEBIAN_FRONTEND=noninteractive apt-get install -y grub-pc
	grub-install --target=i386-pc --recheck --debug $DEVPART
	update-grub2
	;;

[3]* ) 
	echo "You asked to install efi bootloader."
	while ! mount | grep -iq "/boot/efi"; do
		echo "/boot/efi is not mounted. Please mount it."
		read -p "Press any key to continue."
	done
	
	DEBIAN_FRONTEND=noninteractive apt-get install -y grub-efi-amd64
	
	if [[ "$DISTRONUM" -eq "1" || "$DISTRONUM" -eq "2" ]]; then
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --debug
	fi
	
	if [[ "$DISTRONUM" -eq "3" ]]; then
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --debug
	fi
	
	update-grub2
	;;

[4]* ) 
	if [ ! -z $PART ]; then
		echo "Installing grub to $PART."
		DEBIAN_FRONTEND=noninteractive apt-get install -y grub-pc
		grub-install --target=i386-pc --recheck --debug $PART
		update-grub2
	else
		echo "No partition variable specified. Not installing grub."
	fi
	;;

esac

echo "End grubscript.sh"

EOLXYZ

set +e
# Run script in chroot
${CHROOTCMD} /grubscript.sh
set -e

# Delete script when done.
rm ${GRUBSCRIPT}

echo "Script finished successfully."
