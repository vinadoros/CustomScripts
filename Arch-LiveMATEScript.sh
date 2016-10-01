#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR="$SUDO_USER"
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR="$USER"
	else
		export USERNAMEVAR="$(id 1000 -un)"
	fi
	USERGROUP="$(id 1000 -gn)"
	USERHOME="/home/$USERNAMEVAR"
fi

# Date if ISO build.
DATE=$(date +"%F")
# Name of ISO.
ISOFILENAME=archMATEcustom

if [ ! -z "$1" ]; then
	INPUTFOLDER="$(readlink -f $1)"
fi
if [ ! -z "$2" ]; then
	OUTFOLDER="$(readlink -f $2)"
fi

# Set location to perform build and store ISO.
if [ -d "$INPUTFOLDER" ]; then
	ARCHLIVEPATH=$INPUTFOLDER/archlive
	OUTFOLDER=$INPUTFOLDER
else
	ARCHLIVEPATH=$PWD/archlive
	OUTFOLDER=$PWD
fi
if [ ! -d "$OUTFOLDER" ]; then
	OUTFOLDER="$(dirname $ARCHLIVEPATH)"
fi

cleanup () {
	if [ -d "$ARCHLIVEPATH" ]; then
		echo "Removing $ARCHLIVEPATH"
		sudo umount -l $ARCHLIVEPATH/work/mnt/airootfs
		sudo umount -l $ARCHLIVEPATH/work/i686/airootfs
		sudo umount -l $ARCHLIVEPATH/work/x86_64/airootfs
		sudo rm -rf "$ARCHLIVEPATH"
	fi
	if [ -d "${REPOFOLDER}" ]; then
		echo "Removing $REPOFOLDER"
		sudo rm -rf "${REPOFOLDER}"
	fi
}

trap cleanup SIGHUP SIGINT SIGTERM

# Check free space of current folder. If less than 30 gb, error out.
FREESPACE=$(($(stat -f --format="%a*%S" $OUTFOLDER)))
echo "Free Space of $OUTFOLDER is $FREESPACE."
if [[ $FREESPACE -lt 32212254720 ]]; then
	echo "Not enough free space. Exiting."
	cleanup
	exit 0;
fi

# Repo variables

# Folder to build pacakges in.
BUILDFOLDER=/var/tmp

# Folder to store repo in.
REPONAME=localrepo
REPOFOLDER=/var/tmp/${REPONAME}

# Repo Functions

# Function for AUR build.
aur_build(){

	if [ -z "$1" ]; then
		echo "No paramter passed. Returning."
		return 0;
	else
		AURPKG="$1"
	fi

	if [ -f "/var/cache/pacman/pkg/${AURPKG}"* ]; then
		sudo rm "/var/cache/pacman/pkg/${AURPKG}"*
	fi
	cd $BUILDFOLDER
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/${AURPKG}.tar.gz
	tar zxvf ${AURPKG}.tar.gz
	sudo chmod a+rwx -R ${AURPKG}
	cd ${AURPKG}
	makepkg --noconfirm -c -f
	mv ${AURPKG}-*.pkg.tar.xz ../
	cd ..
	rm -rf ${AURPKG}/
	rm ${AURPKG}.tar.gz
}

# Function for building the repo
build_repo(){
	echo "Building Local Repository at ${REPOFOLDER}."
	if stat --printf='' ${BUILDFOLDER}/*-x86_64.pkg.tar.xz 2>/dev/null; then
		sudo mv ${BUILDFOLDER}/*-x86_64.pkg.tar.xz ${REPOFOLDER}/x86_64
	fi
	if stat --printf='' ${BUILDFOLDER}/*-i686.pkg.tar.xz 2>/dev/null; then
		sudo mv ${BUILDFOLDER}/*-i686.pkg.tar.xz ${REPOFOLDER}/i686
	fi
	if stat --printf='' ${BUILDFOLDER}/*-any.pkg.tar.xz 2>/dev/null; then
		sudo mv ${BUILDFOLDER}/*-any.pkg.tar.xz ${REPOFOLDER}/x86_64
		sudo cp ${REPOFOLDER}/x86_64/*-any.pkg.tar.xz ${REPOFOLDER}/i686/
	fi
	repo-add ${REPOFOLDER}/x86_64/${REPONAME}.db.tar.gz ${REPOFOLDER}/x86_64/*.pkg.tar.xz
	repo-add ${REPOFOLDER}/i686/${REPONAME}.db.tar.gz ${REPOFOLDER}/i686/*.pkg.tar.xz
	#~ sudo chmod a+rwx -R ${REPOFOLDER}
	#~ sudo chown 1000:100 -R ${REPOFOLDER}
}

# Install archiso if folders are missing.
if [ ! -d /usr/share/archiso/configs/releng/ ]; then
	sudo pacman -S --needed --noconfirm archiso curl
fi

if [ -d $ARCHLIVEPATH ]; then
	echo "Cleaning existing archlive folder."
	cleanup
fi

cp -r /usr/share/archiso/configs/releng/ $ARCHLIVEPATH

# Enable copytoram, but only for 64bit machiens.
# if ! grep -Fq "copytoram" $ARCHLIVEPATH/syslinux/archiso_sys64.cfg; then
# 	sed -i '/APPEND/ s|$| copytoram=y |' $ARCHLIVEPATH/syslinux/archiso_sys32.cfg
# 	sed -i '/APPEND/ s|$| copytoram=y |' $ARCHLIVEPATH/syslinux/archiso_sys64.cfg
# fi

# Edit build.sh to umount dev (this is a fix for dkms running inside the chroot)
# sed -i '/run_once make_packages_efi/iumount -Rdl ${work_dir}/i686/airootfs || true' "$ARCHLIVEPATH"/build.sh
# sed -i '/run_once make_packages_efi/iumount -Rdl ${work_dir}/x86_64/airootfs || true' "$ARCHLIVEPATH"/build.sh

# Copy script folder to iso root
#~ cp -r "$SCRIPTDIR" "$ARCHLIVEPATH/airootfs/"
git clone "https://github.com/vinadoros/CustomScripts.git" "$ARCHLIVEPATH/airootfs/CustomScripts"
#~ SCRIPTBASENAME="$(basename $SCRIPTDIR)"
SCRIPTBASENAME="CustomScripts"

# Set syslinux timeout
if ! grep -iq "^TIMEOUT" "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"; then
	echo "TIMEOUT 30" >> "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"
	echo "TOTALTIMEOUT 600" >> "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"
fi

# Prepare AUR packages for local repo.
if [ ! -d ${REPOFOLDER} ]; then
	echo "Creating ${REPOFOLDER}."
	mkdir -p ${REPOFOLDER}
	echo "Creating ${REPOFOLDER}/i686."
	mkdir -p ${REPOFOLDER}/i686
	echo "Creating ${REPOFOLDER}/x86_64."
	mkdir -p ${REPOFOLDER}/x86_64
	chmod a+rwx -R ${REPOFOLDER}
fi

# Build software from AUR
# aur_build "debootstrap"

# Build the local repo.
# build_repo

# Add local created repo if it exists to pacman.conf for live disk.
if [[ -d ${REPOFOLDER} && -f ${REPOFOLDER}/i686/localrepo.db ]] && ! grep -ixq "\[${REPONAME}\]" $ARCHLIVEPATH/pacman.conf; then
	echo "Adding ${REPONAME} to $ARCHLIVEPATH/pacman.conf."
	bash -c "cat >>${ARCHLIVEPATH}/pacman.conf" <<EOL
[${REPONAME}]
SigLevel = Optional TrustAll
Server = file://${REPOFOLDER}/\$arch

EOL
fi

sudo sh -c "cat >>$ARCHLIVEPATH/packages.both" <<'EOL'
# My custom packages

# Utilities
zip
unzip
p7zip
unrar
gparted
clonezilla
partimage
fsarchiver
btrfs-progs
xfsprogs
gnome-disk-utility
grsync
smbclient
binutils
git
chntpw
debootstrap
openssh
avahi
nss-mdns
tmux

# Kernel stuff
ipw2200-fw
zd1211-firmware
virtualbox-guest-modules-arch
virtualbox-guest-utils

# Desktop stuff
lxdm
xorg-server
xorg-server-utils
xorg-drivers
mesa-libgl
xorg-xinit
xf86-input-vmmouse
xf86-video-vmware
open-vm-tools
onboard
networkmanager
network-manager-applet
gnome-keyring
gnome-icon-theme
midori
gvfs
gvfs-smb

# Mate Desktop
mate-gtk3

# Mate Extra tools
atril-gtk3
caja-gksu-gtk3
caja-open-terminal-gtk3
engrampa
eom-gtk3
galculator
mate-applets-gtk3
mate-power-manager-gtk3
mate-screensaver-gtk3
mate-system-monitor
mate-terminal
mate-utils-gtk3
pluma-gtk3
mate-icon-theme-faenza
ttf-dejavu
ttf-liberation
EOL

sudo bash -c "cat >>$ARCHLIVEPATH/airootfs/root/customize_airootfs.sh" <<EOLXYZ

set -x
SCRIPTBASENAME="/$SCRIPTBASENAME"

EOLXYZ

sudo bash -c "cat >>$ARCHLIVEPATH/airootfs/root/customize_airootfs.sh" <<'EOLXYZ'

savespace(){
	localepurge
	yes | pacman -Scc
}

if [ $(uname -m) = "x86_64" ]; then
	if ! grep -Fq "multilib" /etc/pacman.conf; then
		cat >>/etc/pacman.conf <<'EOL'

[multilib]
SigLevel = PackageRequired
Include = /etc/pacman.d/mirrorlist
EOL
	fi
fi

# Modules to load on startup
cat >/etc/modules-load.d/bootmodules.conf <<EOL
vboxguest
vboxsf
vboxvideo
vmw_balloon
vmw_pvscsi
vmw_vmci
vmwgfx
vmxnet3
EOL

systemctl enable vboxservice
systemctl enable vmtoolsd
systemctl enable vmware-vmblock-fuse.service

systemctl disable multi-user.target

systemctl -f enable lxdm
sed -i 's/#\ autologin=dgod/autologin=root/g' /etc/lxdm/lxdm.conf
sed -i 's/#\ session=\/usr\/bin\/startlxde/session=\/usr\/bin\/mate-session/g' /etc/lxdm/lxdm.conf

systemctl enable NetworkManager

# Set root password
echo "root:asdf" | chpasswd

# Enable avahi and ssh
systemctl enable sshd
systemctl enable avahi-daemon

# Set computer to not sleep on lid close
if ! grep -Fxq "HandleLidSwitch=lock" /etc/systemd/logind.conf; then
	echo 'HandleLidSwitch=lock' >> /etc/systemd/logind.conf
fi

# --- BEGIN Update CustomScripts on startup ---

cat >/etc/systemd/system/updatecs.service <<EOL
[Unit]
Description=updatecs service
Requires=network-online.target
After=network.target nss-lookup.target network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/bash -c "cd /CustomScripts; git pull"
Restart=on-failure
RestartSec=3s
TimeoutStopSec=7s

[Install]
WantedBy=graphical.target
EOL
systemctl enable updatecs.service

# --- END Update CustomScripts on startup ---

# Add CustomScripts to path
if ! grep "$SCRIPTBASENAME" /root/.zshrc; then
	cat >>/root/.zshrc <<EOLZSH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME
fi
EOLZSH
fi

#savespace

EOLXYZ

cd "$ARCHLIVEPATH"

sudo bash <<EOF
"$ARCHLIVEPATH"/build.sh -v -o "$OUTFOLDER" -N "$ISOFILENAME"
if [ -d "$ARCHLIVEPATH" ]; then
	echo "Removing $ARCHLIVEPATH"
	rm -rf "$ARCHLIVEPATH"
fi
if [ -d "${REPOFOLDER}" ]; then
	echo "Removing $REPOFOLDER"
	rm -rf "${REPOFOLDER}"
fi
chown $USERNAMEVAR:$USERGROUP "$OUTFOLDER/$ISOFILENAME"*
chmod a+rwx "$OUTFOLDER/$ISOFILENAME"*
EOF
