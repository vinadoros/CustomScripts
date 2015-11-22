#!/bin/bash

# Halt on any error.
set -e

###############################################################################
##################        Initial Setup and Variables      ####################
###############################################################################

# Private variable file.
PRIVATEVARS="/usr/local/bin/privateconfig.sh"

#Temporary Mount
TMPMNT=fedora_temp_mount

URL="https://download.fedoraproject.org/pub/fedora/linux/releases/22/Cloud/x86_64/Images/Fedora-Cloud-Base-22-20150521.x86_64.raw.xz"
XZIMG=$(basename ${URL}) # Just the file name
IMG=${XZIMG:0:-3}        # Pull .xz off of the end

if [ "$(id -u)" != "0" ]; then
	echo "Not running as root. Please run the script with sudo or root privledges."
	exit 1;
fi

# Enable installing to guest. Set to 0 if physical machine.
if grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name"; then
	VBOXGUEST=1
	echo "Virtualbox Detected"
else
	VBOXGUEST=0
	echo "Virtualbox not Detected"
fi
if grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor"; then
	QEMUGUEST=1
	echo "QEMU Detected"
else
	QEMUGUEST=0
	echo "QEMU not Detected"
fi
if grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name"; then
	VMWGUEST=1
	echo "VMWare Detected"
else
	VMWGUEST=0
	echo "VMWare not Detected"
fi

if [ -z "$USERNAMEVAR" ]; then
	read -p "Input a user name: " USERNAMEVAR
	USERNAMEVAR=${USERNAMEVAR//[^a-zA-Z0-9_]/}
	if [[ -z "$USERNAMEVAR" && -f "$PRIVATEVARS" ]]; then
		source "$PRIVATEVARS"
		echo "No input found. Defaulting to $USERNAMEVAR."
	fi
fi
echo "You entered" $USERNAMEVAR
USERHOME=/home/$USERNAMEVAR

if [ -z "$FULLNAME" ]; then
	read -p "Input a full name (with spaces): " FULLNAME
	if [[ -z "$FULLNAME" && -f "$PRIVATEVARS" ]]; then
		source "$PRIVATEVARS"
		echo "No input found. Defaulting to $FULLNAME."
	fi
fi
echo "You entered" $FULLNAME

# Strip trailing slash if it exists.
INSTALLPATH=${1%/}
if [ -z "${INSTALLPATH}" ]; then
	echo "No install path found. Exiting."
	exit 1;
else
	echo "Installpath is ${INSTALLPATH}."
fi

#Path above installpath
TOPPATH=${INSTALLPATH}/..

# Chroot command
CHROOTCMD="systemd-nspawn -D ${INSTALLPATH}"

# Input initial variables.
if [ ! -f ${INSTALLPATH}/etc/hostname ]; then
	read -p "Input a computer name: " NEWHOSTNAME
	NEWHOSTNAME=${NEWHOSTNAME//[^a-zA-Z0-9_]/}
	if [ -z "$NEWHOSTNAME" ]; then
		echo "No input found. Defaulting to FedoraTest."
		NEWHOSTNAME=FedoraTest
	fi
	echo "You entered" $NEWHOSTNAME
fi

read -p "Press any key to continue." 

# Create install path
if [ ! -d ${INSTALLPATH} ]; then
	echo "Creating ${INSTALLPATH}."
	mkdir -p ${INSTALLPATH}
	chmod a+rwx ${INSTALLPATH}
fi

if [ ! -f ${INSTALLPATH}/etc/hostname ]; then
	if [ ! -f ${TOPPATH}/${XZIMG} ]; then
		echo "Retrieving Fedora xz image."
		wget -P ${TOPPATH}/ ${URL}
		chmod a+rwx ${TOPPATH}/${XZIMG}
	fi
	if [ ! -f ${TOPPATH}/${IMG} ]; then
		echo "Decompressing xz image."
		xz -d -k ${TOPPATH}/${XZIMG}
		chmod a+rwx ${TOPPATH}/${IMG}
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
	rm ${TOPPATH}/${IMG}
	
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

echo "Grub and linux kernel not installed in this script."

# Delete script when done.
rm ${INSTALLPATH}/setupscript.sh

echo "Script finished successfully."
