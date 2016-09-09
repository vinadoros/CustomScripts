#!/bin/bash

echo "Executing F-ChrootInitVars.sh."

# Private variable file.
PRIVATEVARS="/usr/local/bin/privateconfig.sh"

# Halt on any error.
set -e

MACHINEARCH=$(uname -m)

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

# Strip trailing slash if it exists.
if [ -z "${INSTALLPATH}" ]; then
	INSTALLPATH=$(readlink -f ${1%/})
else
	INSTALLPATH=$(readlink -f ${INSTALLPATH%/})
fi
if [ -z "${INSTALLPATH}" ]; then
	echo "No install path found. Exiting."
	exit 1;
else
	echo "Installpath is ${INSTALLPATH}."
fi

SETUPSCRIPT="${INSTALLPATH}/setupscript.sh"
GRUBSCRIPT="${INSTALLPATH}/grubscript.sh"
echo "Initial chroot script is ${SETUPSCRIPT}."
echo "Grub script is ${GRUBSCRIPT}."
if [ -f ${SETUPSCRIPT} ]; then
	echo "Removing existing script at ${SETUPSCRIPT}."
	rm -f ${SETUPSCRIPT}
fi
if [ -f ${GRUBSCRIPT} ]; then
	echo "Removing existing script at ${GRUBSCRIPT}."
	rm -f ${GRUBSCRIPT}
fi

# Input initial variables.

if [ ! -f "${INSTALLPATH}/etc/hostname" ]; then
	if [ -z "$NEWHOSTNAME" ]; then
		read -p "Input a computer name: " NEWHOSTNAME
		NEWHOSTNAME=${NEWHOSTNAME//[^a-zA-Z0-9_-]/}
		if [ -z "$NEWHOSTNAME" ]; then
			NEWHOSTNAME=Test
			echo "No input found. Defaulting to $NEWHOSTNAME."
		fi
	fi
	echo "You entered" $NEWHOSTNAME
fi

if [ -z "$USERNAMEVAR" ]; then
	read -p "Input a user name: " USERNAMEVAR
	USERNAMEVAR=${USERNAMEVAR//[^a-zA-Z0-9_]/}
	if [[ -z "$USERNAMEVAR" && -f "$PRIVATEVARS" ]]; then
		source "$PRIVATEVARS"
		USERNAMEVAR="$DEFAULTUSERNAMEVAR"
		echo "No input found. Defaulting to $USERNAMEVAR."
	elif [[ -z "$USERNAMEVAR" && ! -f "$PRIVATEVARS" ]]; then
		USERNAMEVAR="user"
		echo "No input found. Defaulting to $USERNAMEVAR."
	fi
fi
echo "You entered" $USERNAMEVAR
USERHOME=/home/$USERNAMEVAR

if [ -z "$FULLNAME" ]; then
	read -p "Input a full name (with spaces): " FULLNAME
	if [[ -z "$FULLNAME" && -f "$PRIVATEVARS" ]]; then
		source "$PRIVATEVARS"
		FULLNAME="$DEFAULTFULLNAME"
		echo "No input found. Defaulting to $FULLNAME."
	elif [[ -z "$FULLNAME" && ! -f "$PRIVATEVARS" ]]; then
		FULLNAME="user"
		echo "No input found. Defaulting to $FULLNAME."
	fi
fi
echo "You entered" $FULLNAME

if [ -z "$SETPASS" ]; then
	echo "Input a user and root password: "
	read -s PASSWORD
	echo "Please confirm password: "
	read -s PASSWORD2
	if [[ -z "$PASSWORD" ]]; then
		echo "No password found. Exiting."
		exit 1;
	fi
	while [[ "$PASSWORD" != "$PASSWORD2" ]]; do
		echo "Passwords do not match."
		echo "Input a user and root password: "
		read -s PASSWORD
		echo "Please confirm password: "
		read -s PASSWORD2
	done
	SETPASS="${PASSWORD}"
fi

# Grub and linux install section
set +e
DEVPART=$(sh -c df -m | grep " \+${INSTALLPATH}$" | grep -Eo '/dev/[a-z]d[a-z]')
set -e

[ -z "$SETGRUB" ] && SETGRUB="0"
while [[ "${SETGRUB}" -le "0" || "${SETGRUB}" -gt "4" ]]; do
	read -p "Enter 2 to perform 'grub-install $DEVPART', 3 to install efi bootloader (make sure /boot/efi is mounted), or 4 to 'grub-install' to a custom partition. Enter 1 to do nothing. (1/2/3/4)" SETGRUB
    case $SETGRUB in
    [1] )
	echo "You asked to not install a bootloader."
	;;
	[2] )
	echo "You asked to perform 'grub-install $DEVPART'."
	;;
	[3] )
	echo "You asked to install efi bootloader. Ensure boot/efi is mounted in the chroot."
	;;
	[4] )
	echo "You asked to perform grub-install with a custom partition."

	read -p "Enter the partition to grub-install to (i.e. /dev/sda1): " PART
	if [ -z "$PART" ]; then
		PART=/dev/vda
	fi
	echo "You entered $PART."
	;;
	* ) echo "Please input a number (1,2,3,4)."
	;;
    esac
done


# Create initial portion of script for chroot.
bash -c "cat >>${SETUPSCRIPT}" <<EOLXYZ
#!/bin/bash

echo "Running ${SETUPSCRIPT}"

# Carry-over variables
USERNAMEVAR=${USERNAMEVAR}
USERHOME=${USERHOME}
NEWHOSTNAME=${NEWHOSTNAME}
FULLNAME=$(echo \"${FULLNAME}\")
VBOXGUEST=${VBOXGUEST}
QEMUGUEST=${QEMUGUEST}
VMWGUEST=${VMWGUEST}
SETPASS=$(echo \"${SETPASS}\")
MACHINEARCH=${MACHINEARCH}
EOLXYZ
chmod a+rwx "${SETUPSCRIPT}"

# Create initial portion of grub script for chroot.
bash -c "cat >>${GRUBSCRIPT}" <<EOLXYZ
#!/bin/bash

echo "Running ${GRUBSCRIPT}"

# Carry-over variables
DEVPART=${DEVPART}
SETGRUB=${SETGRUB}
PART=${PART}
EOLXYZ
chmod a+rwx "${GRUBSCRIPT}"

# Chroot command
SNCHROOTCMD="systemd-nspawn -D ${INSTALLPATH}"
ACCHROOTCMD="arch-chroot ${INSTALLPATH}"
