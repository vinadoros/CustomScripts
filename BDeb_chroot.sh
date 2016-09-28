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

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

NOPROMPT=0

# Debian stable release
DIST_DEBSTABLE=jessie
# Debian unstable release
DIST_DEBUNSTABLE=unstable
# Ubuntu release
DIST_UBUNTU=xenial

UBUNTUURL="http://archive.ubuntu.com/ubuntu/"
UBUNTUARMURL="http://ports.ubuntu.com/ubuntu-ports/"
# Debian URL is blank because debootstrap chooses a reliable URL.
DEBIANURL=""

usage () {
	echo "h - help"
	echo "a - Debian architecture (i.e. amd64, i386, armhf, etc)"
	echo "b - Distro number (1=Debian Stable, 2=Debian Unstable, 3=Ubuntu ${DIST_UBUNTU}, 4=Custom Ubuntu release.)"
	echo "c - Hostname"
	echo "u - Username"
	echo "f - Full Name"
	echo "v - Password"
	echo "g - Grub Install Number"
	echo "p - Install Path"
	echo "n - Do not prompt to continue."
	exit 0;
}

# Get options
while getopts ":a:b:c:u:f:v:g:p:nh" OPT
do
	case $OPT in
		h)
			echo "Select a valid option."
			usage
			;;
		a)
			DEBARCH="$OPTARG"
			;;
		b)
			DISTRONUM="$OPTARG"
			;;
		c)
			NEWHOSTNAME="$OPTARG"
			;;
		u)
			USERNAMEVAR="$OPTARG"
			;;
		f)
			FULLNAME="$OPTARG"
			;;
		v)
			SETPASS="$OPTARG"
			;;
		g)
			SETGRUB="$OPTARG"
			;;
		p)
			INSTALLPATH="$OPTARG"
			;;
		n)
			NOPROMPT=1
			;;
		\?)
			echo "Invalid option: -$OPTARG" 1>&2
			usage
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument" 1>&2
			usage
			exit 1
			;;
	esac
done

source "$SCRIPTDIR/F-ChrootInitVars.sh"

if [ -z "$DEBARCH" ]; then
	DEBARCH=amd64
	read -p "Input architecture (amd64, i386, armhf, etc): " DEBARCH
	if [ -z "$DEBARCH" ]; then
		echo "No input found. Defaulting to amd64."
		DEBARCH=amd64
	fi
fi
echo "Install architecture is ${DEBARCH}."

[ -z "$DISTROCHOICE" ] && DISTROCHOICE="0"
[ -z "$DISTRONUM" ] && DISTRONUM="0"
while [[ "${DISTRONUM}" -le "0" || "${DISTRONUM}" -gt "4" ]]; do
    read -p "Choose a distro (1=Debian Stable, 2=Debian Unstable, 3=Ubuntu ${DIST_UBUNTU}, 4=Custom Ubuntu release.)" DISTRONUM
    case $DISTRONUM in
    [1-4] )
	;;
	* ) echo "Please input a number."
	;;
	esac
done

case $DISTRONUM in
  [1] )
	DISTROCHOICE=${DIST_DEBSTABLE}
	URL=$DEBIANURL
	;;
	[2] )
	DISTROCHOICE=${DIST_DEBUNSTABLE}
	URL=$DEBIANURL
	;;
	[3] )
	DISTROCHOICE=${DIST_UBUNTU}
	if [ ${DEBARCH} = "armhf" ]; then
		URL=${UBUNTUARMURL}
	else
		URL=${UBUNTUURL}
	fi
	;;
	[4] )
	read -p "Enter an Ubuntu release:" DISTROCHOICE
	if [ ${DEBARCH} = "armhf" ]; then
		URL=${UBUNTUARMURL}
	else
		URL=${UBUNTUURL}
	fi
	;;
	* )
	echo "Error, invalid distro number $DISTRONUM detected. Exiting."
	exit 1;
	;;
esac

echo "Installing ${DISTROCHOICE}."
echo "Debootstrap will install ${DEBARCH} ${DISTROCHOICE} to ${INSTALLPATH} using ${URL}."
if [[ $NOPROMPT != 1 ]]; then
	read -p "Press any key to continue."
fi

# Create install path
if [ ! -d ${INSTALLPATH} ]; then
	echo "Creating ${INSTALLPATH}."
	mkdir -p ${INSTALLPATH}
	chmod a+rwx ${INSTALLPATH}
fi

# Debootstrap
if [ ! -f "${INSTALLPATH}/etc/hostname" ]; then
	if [[ ${DEBARCH} = "i386" || ${DEBARCH} = "amd64" ]]; then
		debootstrap --no-check-gpg --arch ${DEBARCH} ${DISTROCHOICE} ${INSTALLPATH} ${URL}
		# || : forces error code of genfstab to be 0 if it fails, like if the path isn't a mount point.
		genfstab -Up ${INSTALLPATH} > ${INSTALLPATH}/etc/fstab || :

	elif [[ ${DEBARCH} = "armhf" ]]; then
		if [[ ! $(type -P update-binfmts) || ! $(type -P qemu-arm-static) ]]; then
			echo "No qemu-arm-static or update-binfmts binaries found. Exiting."
			exit 1;
		fi
		debootstrap --foreign --no-check-gpg --include=ca-certificates --arch ${DEBARCH} ${DISTROCHOICE} ${INSTALLPATH} ${URL}
		cp /usr/bin/qemu-arm-static ${INSTALLPATH}/usr/bin
		update-binfmts --enable
		chroot ${INSTALLPATH}/ /debootstrap/debootstrap --second-stage --verbose
	else
		echo "No valid architecture detected. Skipping Debootstrap and exiting."
		exit 1;
	fi
	echo "America/New_York" > "${INSTALLPATH}/etc/timezone"
	sed -i 's/\(127.0.0.1\tlocalhost\)\(.*\)/\1 '${NEWHOSTNAME}'/g' "${INSTALLPATH}/etc/hosts"
	echo "${NEWHOSTNAME}" > "${INSTALLPATH}/etc/hostname"
else
	echo "${INSTALLPATH} not empty. Skipping debootstrap."
fi


if [[ ${DISTROCHOICE} = ${DIST_UBUNTU} && -L ${INSTALLPATH}/etc/resolv.conf ]]; then
	# Remove resolv.conf and replace with symlink.
	echo "Removing resolv.conf symlink for Ubuntu."
	rm -f ${INSTALLPATH}/etc/resolv.conf
fi

# Create initial portion of script for chroot.
bash -c "cat >>${SETUPSCRIPT}" <<EOLXYZ
DEBARCH=${DEBARCH}
URL=${URL}

EOLXYZ

# Create main part of setup script for chroot.
bash -c "cat >>${SETUPSCRIPT}" <<'EOLXYZ'
# Exporting Path for chroot
export PATH=$PATH:/bin:/usr/local/sbin:/usr/sbin:/sbin

# Force armhf ubuntu to set-up cleanly.
apt-get install -fy --force-yes

apt-get update

# Install locales
apt-get install -y locales
locale-gen --purge en_US en_US.UTF-8
dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG="en_US.UTF-8"'>/etc/default/locale
dpkg-reconfigure --frontend=noninteractive locales
update-locale
# Locale fix for gnome-terminal.
localectl set-locale LANG="en_US.UTF-8"
# Set keymap for Ubuntu
echo "console-setup	console-setup/charmap47	select	UTF-8" | debconf-set-selections

# Install lsb_release
DEBIAN_FRONTEND=noninteractive apt-get install -y lsb-release nano sudo less apt-transport-https

# Store distro being used.
DISTRO=$(lsb_release -si)
DEBRELEASE=$(lsb_release -sc)
echo Distro used is: ${DISTRO}. Release used is: ${DEBRELEASE}

DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common

if [ ${DISTRO} = "Debian" ]; then
	# Contrib and non-free for normal distro
	add-apt-repository main
	add-apt-repository contrib
	add-apt-repository non-free
	if [[ $DEBRELEASE != "sid" && $DEBRELEASE != "unstable" && $DEBRELEASE != "testing" ]] && ! grep -i "$DEBRELEASE-updates main" /etc/apt/sources.list; then
		add-apt-repository "deb http://ftp.us.debian.org/debian $DEBRELEASE-updates main contrib non-free"
	fi
	# Comment out lines containing httpredir.
	sed -i '/httpredir/ s/^#*/#/' /etc/apt/sources.list
fi

if [ ${DISTRO} = "Ubuntu" ]; then
	# Restricted, universe, and multiverse for Ubuntu.
	add-apt-repository restricted
	add-apt-repository universe
	add-apt-repository multiverse
	if ! grep -i "${DEBRELEASE}-updates main" /etc/apt/sources.list; then
		add-apt-repository "deb ${URL} ${DEBRELEASE}-updates main restricted universe multiverse"
	fi
	if ! grep -i "${DEBRELEASE}-security main" /etc/apt/sources.list; then
		add-apt-repository "deb ${URL} ${DEBRELEASE}-security main restricted universe multiverse"
	fi
	if ! grep -i "${DEBRELEASE}-backports main" /etc/apt/sources.list; then
		add-apt-repository "deb ${URL} ${DEBRELEASE}-backports main restricted universe multiverse"
	fi

fi

apt-get update
apt-get dist-upgrade -y

# Delete defaults in sudoers for Debian.
if grep -iq $'^Defaults\tenv_reset' /etc/sudoers; then
	sed -i $'/^Defaults\tenv_reset/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tmail_badpass/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults\tsecure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c

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
	adduser --disabled-password --gecos "" ${USERNAMEVAR}
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
	usermod -aG daemon,bin,sys,adm,tty,disk,lp,mail,news,uucp,man,proxy,kmem,dialout,fax,voice,cdrom,floppy,tape,sudo,audio,dip,www-data,backup,operator,list,irc,src,gnats,shadow,utmp,video,sasl,plugdev,staff,games,users,netdev,crontab,systemd-journal ${USERNAMEVAR}
	chfn -f "${FULLNAME}" ${USERNAMEVAR}
	if ! grep 'export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin' $USERHOME/.profile; then
		echo 'export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin' | tee -a $USERHOME/.profile
	fi
fi

DEBIAN_FRONTEND=noninteractive apt-get install -y synaptic tasksel xorg

# Install openssh
apt-get install -y ssh

# Install essential programs for startup
DEBIAN_FRONTEND=noninteractive apt-get install -y btrfs-tools f2fs-tools nbd-client

# Enable 32-bit support for 64-bit arch.
if [[ "$DEBARCH" = "amd64" ]]; then
	dpkg --add-architecture i386
fi

# Fetch scripts
apt-get install -y git
git clone "https://github.com/vinadoros/CustomScripts.git" "/opt/CustomScripts"
chmod a+rwx "/opt/CustomScripts"

# Install network manager last, it disables internet access.
apt-get install -y network-manager

# Ubuntu symlink command: ln -sf ../run/resolvconf/resolv.conf /etc/resolv.conf

EOLXYZ

set +e
# Run script in chroot
${SNCHROOTCMD} /setupscript.sh
set -e

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

# Grub Script Section

# Create initial portion of grub script for chroot.
bash -c "cat >>${GRUBSCRIPT}" <<EOLXYZ
DEBARCH=${DEBARCH}
DISTRONUM=${DISTRONUM}

EOLXYZ

# Create main part of grub script for chroot.
bash -c "cat >>${GRUBSCRIPT}" <<'EOLXYZ'
export PATH=$PATH:/bin:/usr/local/sbin:/usr/sbin:/sbin

case $SETGRUB in
[1])
	echo "Not installing kernel."
	;;
[2-4])
	echo "Installing kernel."

<<COMMENT2
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
COMMENT2

	if [[ "$DISTRONUM" -eq "1" || "$DISTRONUM" -eq "2" ]]; then

		if [[ "$DEBARCH" = "amd64" ]]; then
			DEBIAN_FRONTEND=noninteractive apt-get install -y linux-image-amd64
		fi
		if [[ "$DEBARCH" = "i386" || "$DEBARCH" = "i686" ]]; then
			DEBIAN_FRONTEND=noninteractive apt-get install -y linux-image-686-pae
		fi

		apt-get install -y firmware-linux gfxboot
		echo "firmware-ipw2x00 firmware-ipw2x00/license/accepted boolean true" | debconf-set-selections
		echo "firmware-ivtv firmware-ivtv/license/accepted boolean true" | debconf-set-selections
		DEBIAN_FRONTEND=noninteractive apt-get install -y ^firmware-*
	fi

	if [[ "$DISTRONUM" -eq "3" ]]; then
		DEBIAN_FRONTEND=noninteractive apt-get install -y linux-image-generic linux-headers-generic
		DEBIAN_FRONTEND=noninteractive apt-get install -y gfxboot gfxboot-theme-ubuntu linux-firmware
	fi
	;;

esac

case $SETGRUB in

[1]* )
	echo "You asked to do nothing. Be sure to install a bootloader."
	;;

[2]* )
	echo "You asked to perform 'grub-install $DEVPART'."
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
${ACCHROOTCMD} /grubscript.sh
set -e

# Delete script when done.
rm ${GRUBSCRIPT}

echo "Script finished successfully."
echo -e "\n"
