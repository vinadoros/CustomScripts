#!/bin/bash
set -eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Date if ISO build.
DATE=$(date +"%F")
# Name of ISO.
ISOFILENAME=archMATEcustom

# Set location to perform build and store ISO.
if [ -d /mnt/Storage ]; then
	ARCHLIVEPATH=/mnt/Storage/archlive
	OUTFOLDER=/mnt/Storage
elif [ -d /media/sf_Storage ]; then
	ARCHLIVEPATH=~/archlive
	OUTFOLDER=/media/sf_Storage
else
	ARCHLIVEPATH=~/archlive
	OUTFOLDER=~
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
	if [ -f "/var/cache/pacman/pkg/debootstrap"* ]; then 
		sudo rm "/var/cache/pacman/pkg/debootstrap"*
	fi
	cd $BUILDFOLDER
	wget https://aur4.archlinux.org/cgit/aur.git/snapshot/${AURPKG}.tar.gz
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
	set +e
	sudo umount -l $ARCHLIVEPATH/work/mnt/airootfs
	sudo umount -l $ARCHLIVEPATH/work/i686/airootfs
	sudo umount -l $ARCHLIVEPATH/work/x86_64/airootfs
	sudo rm -rf $ARCHLIVEPATH
	set -e
fi

# Clean local repo if it exists.
if [ -d ${REPOFOLDER} ]; then
	rm -rf ${REPOFOLDER}
fi

cp -r /usr/share/archiso/configs/releng/ $ARCHLIVEPATH

<<"COMMENT5"
if ! grep -Fq "copytoram" $ARCHLIVEPATH/syslinux/archiso_sys64.cfg; then
	sed -i '/APPEND/ s|$| copytoram=y |' $ARCHLIVEPATH/syslinux/archiso_sys32.cfg
	sed -i '/APPEND/ s|$| copytoram=y |' $ARCHLIVEPATH/syslinux/archiso_sys64.cfg
fi
COMMENT5

# Copy script folder to iso root
#~ cp -r "$SCRIPTDIR" "$ARCHLIVEPATH/airootfs/"
git clone "https://github.com/vinadoros/CustomScripts.git" "$ARCHLIVEPATH/airootfs/CustomScripts"
#~ SCRIPTBASENAME="$(basename $SCRIPTDIR)"
SCRIPTBASENAME="CustomScripts"

# Set syslinux timeout
if ! grep -iq "^TIMEOUT" "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"; then
	echo "TIMEOUT 50" >> "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"
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

# Build debootstrap from AUR
AURPKG=debootstrap
aur_build

# Build the local repo.
build_repo

# Add local created repo if it exists to pacman.conf for live disk.
if [ -d ${REPOFOLDER} ] && ! grep -ixq "\[${REPONAME}\]" $ARCHLIVEPATH/pacman.conf; then
	echo "Adding ${REPONAME} to $ARCHLIVEPATH/pacman.conf."
	bash -c "cat >>${ARCHLIVEPATH}/pacman.conf" <<EOL
[${REPONAME}]
SigLevel = Optional TrustAll
Server = file://${REPOFOLDER}/\$arch

EOL
fi

if ! grep -Fq "lxdm" $ARCHLIVEPATH/packages.both; then
	sudo sh -c "cat >>$ARCHLIVEPATH/packages.both" <<'EOL'
ipw2200-fw
zd1211-firmware
xorg-server
xorg-server-utils
xorg-drivers
mesa-libgl
xorg-xinit
virtualbox-guest-modules
virtualbox-guest-utils
xf86-input-vmmouse
xf86-video-vmware
open-vm-tools
mate
mate-extra
networkmanager
network-manager-applet
gnome-keyring
gnome-icon-theme
zip
unzip
p7zip
unrar
lxdm
gparted
clonezilla
partimage
fsarchiver
btrfs-progs
xfsprogs
gnome-disk-utility
midori
grsync
smbclient
gvfs
gvfs-smb
binutils
git
debootstrap
EOL
fi

if ! grep -Fq "$SCRIPTBASENAME" $ARCHLIVEPATH/airootfs/root/customize_airootfs.sh; then
	sudo sh -c "cat >>$ARCHLIVEPATH/airootfs/root/customize_airootfs.sh" <<EOLXYZ

SCRIPTBASENAME="/$SCRIPTBASENAME"

EOLXYZ
fi

if ! grep -Fq "Arch-Plain.sh" $ARCHLIVEPATH/airootfs/root/customize_airootfs.sh; then
	sudo sh -c "cat >>$ARCHLIVEPATH/airootfs/root/customize_airootfs.sh" <<'EOLXYZ'

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

# Virtualbox stuff
cat >/etc/modules-load.d/virtualbox.conf <<EOL
vboxguest
vboxsf
vboxvideo
EOL

systemctl enable vboxservice
systemctl enable vmtoolsd
systemctl enable vmware-vmblock-fuse.service

systemctl disable multi-user.target

systemctl -f enable lxdm
sed -i 's/#\ autologin=dgod/autologin=root/g' /etc/lxdm/lxdm.conf
sed -i 's/#\ session=\/usr\/bin\/startlxde/session=\/usr\/bin\/mate-session/g' /etc/lxdm/lxdm.conf

systemctl enable NetworkManager

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
fi

cd $ARCHLIVEPATH


sudo bash <<EOF
"$ARCHLIVEPATH"/build.sh -v -o "$OUTFOLDER" -N "$ISOFILENAME"
rm -rf "$ARCHLIVEPATH"
if [ -d "${REPOFOLDER}" ]; then
	rm -rf "${REPOFOLDER}"
fi
chown $USER:users "$OUTFOLDER/$ISOFILENAME"*
chmod a+rwx "$OUTFOLDER/$ISOFILENAME"*
EOF

