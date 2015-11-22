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

source "$SCRIPTDIR/F-ChrootInitVars.sh"

MACHINEARCH=$(uname -m)

echo "Pacstrap will install to ${INSTALLPATH}."
read -p "Press any key to continue." 

# Create install path
if [ ! -d ${INSTALLPATH} ]; then
	echo "Creating ${INSTALLPATH}."
	mkdir -p ${INSTALLPATH}
	chmod a+rwx ${INSTALLPATH}
fi

# Pacstrap
if [ ! -f ${INSTALLPATH}/etc/hostname ]; then
	pacstrap -d "${INSTALLPATH}" base base-devel
	genfstab -Up "${INSTALLPATH}" > "${INSTALLPATH}/etc/fstab"
	echo "LANG=en_US.UTF-8" > "${INSTALLPATH}/etc/locale.conf"
	sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' "${INSTALLPATH}/etc/locale.gen"
	sed -i 's/\(127.0.0.1\tlocalhost.localdomain\tlocalhost\)\(.*\)/\1 '$NEWHOSTNAME'/g' "${INSTALLPATH}/etc/hosts"
	echo "${NEWHOSTNAME}" > "${INSTALLPATH}/etc/hostname"
else
	echo "${INSTALLPATH} not empty. Skipping pacstrap."
fi

# Create main part of setup script for chroot.
bash -c "cat >>${SETUPSCRIPT}" <<'EOLXYZ'
locale-gen
export LANG=en_US.UTF-8
if [ ! -f /etc/localtime ]; then
	ln -s /usr/share/zoneinfo/America/New_York /etc/localtime
fi
#hwclock --systohc --utc

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


if [ $MACHINEARCH == "x86_64" ]; then
    if ! grep -Fxq "[multilib]" /etc/pacman.conf; then
        sh -c "cat >>/etc/pacman.conf" <<'EOL'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOL
    fi
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

# Network Manager and openssh.
pacman -S --needed --noconfirm wget networkmanager dhclient ntfs-3g gptfdisk dosfstools btrfs-progs xfsprogs f2fs-tools openssh
systemctl enable NetworkManager
systemctl enable sshd

#Install xorg, display manger...
pacman -S --needed --noconfirm xorg-server xorg-server-utils xorg-drivers xf86-input-libinput mesa-libgl xorg-xinit xterm mesa mesa-vdpau libva-mesa-driver libva-intel-driver libva-vdpau-driver libva 
# Causes crashing in chroots.
#pacman -S --needed --noconfirm libvdpau-va-gl
if [ $MACHINEARCH == "x86_64" ]; then
	pacman -S --needed --noconfirm lib32-mesa-vdpau
fi

pacman -S --needed --noconfirm network-manager-applet gnome-keyring gnome-icon-theme ipw2200-fw dosfstools system-config-printer alsa-utils

#Install openbox
pacman -S --needed --noconfirm openbox

usermod -aG lp,network,video,audio,storage,scanner,power,disk,sys,games,optical,avahi $USERNAMEVAR

# Install apacman (allows installation of packages using root).
if ! pacman -Q "apacman" >/dev/null; then
	pacman -S --needed --noconfirm binutils ca-certificates curl fakeroot file grep jshon sed tar wget
	curl -O https://aur4.archlinux.org/cgit/aur.git/snapshot/apacman.tar.gz
	tar zxvf apacman.tar.gz
	chmod 777 -R apacman
	cd apacman
	su nobody -s /bin/bash <<'EOL'
		makepkg --noconfirm -s
EOL
	pacman -U --noconfirm ./apacman-*.pkg.tar.xz
	cd ..
	rm -f apacman.tar.gz
	rm -rf ./apacman
fi

EOLXYZ

set +e
# Run script in chroot
${ACCHROOTCMD} /setupscript.sh
set -e

# Delete script when done.
rm ${SETUPSCRIPT}

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
if [ -z $SETGRUB ]; then
	read -p "Enter 2 to perform 'grub-install $DEVPART', 3 to install efi bootloader (make sure /boot/efi is mounted), or 4 to 'grub-install' to a custom partition. Enter 1 to do nothing. (1/2/3/4)" SETGRUB
fi
case $SETGRUB in
    [1]* ) 
	echo "You asked to do nothing. Be sure to install a bootloader."
	;;
    
    [2]* ) 
	echo "You asked to perform 'grub-isntall $DEVPART'."
	pacman -S --needed --noconfirm grub os-prober
	grub-install --target=i386-pc --recheck --debug $DEVPART
	;;
	
	[3]* ) 
	echo "You asked to install efi bootloader."
	while ! mount | grep -iq "/boot/efi"; do
		echo "/boot/efi is not mounted. Please mount it."
		read -p "Press any key to continue."
	done
	pacman -S --needed --noconfirm efibootmgr os-prober grub
	grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch --recheck --debug
	;;
	
	[4]* ) 
	echo "You asked to perform grub-install with a custom partition."
	if [ ! -z $PART ]; then
		echo "Installing grub to $PART."
		DEBIAN_FRONTEND=noninteractive apt-get install -y grub-pc
		grub-install --target=i386-pc --recheck --debug $PART
	else
		echo "No partition variable specified. Not installing grub."
	fi
	;;
esac

case $SETGRUB in
	[2-4] )
	if grep -iq GenuineIntel /proc/cpuinfo; then
		echo "Installing Intel Microcode."
		pacman -S --needed --noconfirm intel-ucode
	fi
	echo "Generating grub.cfg"
	if [ -f /etc/grub.d/30_os-prober ]; then
		sudo chmod a-x /etc/grub.d/30_os-prober
	fi
	grub-mkconfig -o /boot/grub/grub.cfg
	if [ -f /etc/grub.d/30_os-prober ]; then
		sudo chmod a+x /etc/grub.d/30_os-prober
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

# Run the F-ChrootOnly script if no bootloader/kernel installed.
#~ [ $SETGRUB -eq 1 ] && source "$SCRIPTDIR/F-ChrootOnly.sh"

# Create new setup script for post-install tasks.
echo "Creating post-install setup script."
"$SCRIPTDIR/NArch.sh" "${INSTALLPATH}"

echo -e "\nScript finished successfully.\n"


