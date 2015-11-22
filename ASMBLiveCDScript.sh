#!/bin/bash
set -eu

# Date if ISO build.
DATE=$(date +"%F")
# Name of ISO.
ISOFILENAME=SMBLive

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
BUILDFOLDER=/tmp

# Folder to store repo in.
REPONAME=localrepo
REPOFOLDER=/tmp/${REPONAME}

# Repo Functions

# Function for AUR build.
aur_build(){
	cd $BUILDFOLDER
	#AUR2LTR=$(echo "${AURPKG}" | cut -c-2)
	wget https://aur4.archlinux.org/cgit/aur.git/snapshot/${AURPKG}.tar.gz
	#curl -O https://aur.archlinux.org/packages/${AUR2LTR}/${AURPKG}/${AURPKG}.tar.gz
	tar zxvf ${AURPKG}.tar.gz
	sudo chmod a+rwx -R ${AURPKG}
	cd ${AURPKG}
	sudo su nobody -s /bin/bash <<'EOL'
		makepkg --noconfirm -c -f
EOL
	sudo chmod a+rwx ${AURPKG}-*.pkg.tar.xz
	sudo chown 1000:100 ${AURPKG}-*.pkg.tar.xz
	sudo mv ${AURPKG}-*.pkg.tar.xz ../
	cd ..
	sudo rm -rf ${AURPKG}/
	sudo rm ${AURPKG}.tar.gz
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
	sudo repo-add ${REPOFOLDER}/x86_64/${REPONAME}.db.tar.gz ${REPOFOLDER}/x86_64/*.pkg.tar.xz
	sudo repo-add ${REPOFOLDER}/i686/${REPONAME}.db.tar.gz ${REPOFOLDER}/i686/*.pkg.tar.xz
	sudo chmod a+rwx -R ${REPOFOLDER}
	sudo chown 1000:100 -R ${REPOFOLDER}
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

# Set syslinux timeout
if ! grep -iq "^TIMEOUT" "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"; then
	echo "TIMEOUT 20" >> "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"
	echo "TOTALTIMEOUT 600" >> "$ARCHLIVEPATH/syslinux/archiso_sys_both_inc.cfg"
fi

# Set hostname
echo "driveserver" > $ARCHLIVEPATH/airootfs/etc/hostname

# Delete i686
sed -i 's/ i686//g' $ARCHLIVEPATH/build.sh

<<"COMMENT5"
if ! grep -Fq "copytoram" $ARCHLIVEPATH/syslinux/archiso_sys64.cfg; then
	sed -i '/APPEND/ s|$| copytoram=y |' $ARCHLIVEPATH/syslinux/archiso_sys32.cfg
	sed -i '/APPEND/ s|$| copytoram=y |' $ARCHLIVEPATH/syslinux/archiso_sys64.cfg
fi
COMMENT5



# Prepare AUR packages for local repo.
#~ if [ ! -d ${REPOFOLDER} ]; then
	#~ echo "Creating ${REPOFOLDER}."
	#~ mkdir -p ${REPOFOLDER}
	#~ echo "Creating ${REPOFOLDER}/i686."
	#~ mkdir -p ${REPOFOLDER}/i686
	#~ echo "Creating ${REPOFOLDER}/x86_64."
	#~ mkdir -p ${REPOFOLDER}/x86_64
	#~ chmod 777 -R ${REPOFOLDER}
#~ fi

# Build debootstrap from AUR
#AURPKG=debootstrap
#aur_build

# Build apacman from AUR
#AURPKG=apacman
#AUR2LTR=ap
#aur_build

# Build the local repo
#build_repo

# Add local created repo if it exists to pacman.conf for live disk.
#~ if [ -d ${REPOFOLDER} ] && ! grep -ixq "\[${REPONAME}\]" $ARCHLIVEPATH/pacman.conf; then
	#~ echo "Adding ${REPONAME} to $ARCHLIVEPATH/pacman.conf."
	#~ bash -c "cat >>${ARCHLIVEPATH}/pacman.conf" <<EOL
#~ [${REPONAME}]
#~ SigLevel = Optional TrustAll
#~ Server = file://${REPOFOLDER}/\$arch

#~ EOL
#~ fi


if ! grep -Fq "lxdm" $ARCHLIVEPATH/packages.both; then
	sudo sh -c "cat >>$ARCHLIVEPATH/packages.both" <<'EOL'
virtualbox-guest-utils-nox
virtualbox-guest-modules
open-vm-tools
btrfs-progs
xfsprogs
samba
EOL
fi


if ! grep -Fq "Arch-Plain.sh" $ARCHLIVEPATH/airootfs/root/customize_airootfs.sh; then
	sudo sh -c "cat >>$ARCHLIVEPATH/airootfs/root/customize_airootfs.sh" <<'EOLXYZ'

# Virtualbox stuff
if [ ! -f /etc/modules-load.d/virtualbox.conf ]; then
	cat >>/etc/modules-load.d/virtualbox.conf <<EOL
vboxguest
vboxsf
vboxvideo
EOL
fi

# Vmware stuff
if [ ! -f /etc/modules-load.d/vmware-guest.conf ]; then
	cat >>/etc/modules-load.d/vmware-guest.conf <<EOL
vmw_balloon
vmw_pvscsi
vmw_vmci
vmwgfx
vmxnet3
vmw_vsock_vmci_transport
EOL
fi

# Qemu stuff
if [ ! -f /etc/modules-load.d/qemu-guest.conf ]; then
	cat >>/etc/modules-load.d/qemu-guest.conf <<EOL
virtio
virtio_pci
virtio_blk
virtio_net
virtio_ring
EOL
fi

systemctl enable vboxservice
systemctl enable vmtoolsd

# Set computer to not sleep on lid close
if ! grep -Fxq "HandleLidSwitch=lock" /etc/systemd/logind.conf; then
	echo 'HandleLidSwitch=lock' >> /etc/systemd/logind.conf
fi

# NTP
systemctl enable systemd-timesyncd

# Samba
systemctl enable smbd
systemctl enable nmbd
systemctl enable winbindd
# Set up smb.conf
if [ ! -f /etc/samba/smb.conf ]; then
	touch /etc/samba/smb.conf
fi

# Add a 1000 user
useradd user -u 1000

if ! grep -iq "\[Drives\]" /etc/samba/smb.conf; then
	echo "Adding Drives share for samba to smb.conf."
	bash -c "cat >>/etc/samba/smb.conf" <<EOL

[Drives]
	force user = user
	user = root
	write list = root
	writeable = yes
	force group = users
	valid users = root
	path = /mnt
	delete readonly = yes
	create mask = 0777
	directory mask = 0777

EOL
fi
# Set samba password for root from stdin
echo -e "asdf\nasdf" | pdbedit -a -u root -t

if [ -d /mnt ]; then
	chmod a+rwx /mnt
fi

# Create mount script.
MNTSCRIPT=/usr/local/bin/mounter.sh
bash -c "cat >>$MNTSCRIPT" <<'EOLABC'
#!/bin/bash

partmountcmd () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		DRIVEDISKNAME="$1"
		DRIVEDISKPATH="/dev/$DRIVEDISKNAME"
	fi
	
	if [ -b "$DRIVEDISKPATH" ]; then
		for v_partition in $(parted -s "$DRIVEDISKPATH" print|awk '/^ / {print $1}'); do
			DRIVEPART="${DRIVEDISKPATH}${v_partition}"
			DRIVEPARTNAME="${DRIVEDISKNAME}${v_partition}"
			if [[ -b "$DRIVEPART" && ! -z "${v_partition}" ]]; then
				echo "Mounting ${DRIVEPART}"
				mkdir -p "/mnt/${DRIVEPARTNAME}"
				mount "${DRIVEPART}" "/mnt/${DRIVEPARTNAME}"
			fi
		done
		if [[ ! -b "${DRIVEDISKPATH}1" && ! -b "${DRIVEDISKPATH}2" && ! -b "${DRIVEDISKPATH}3" ]]; then
			echo "Mounting ${DRIVEDISKPATH}"
			mkdir -p "/mnt/${DRIVEDISKNAME}"
			mount "${DRIVEPART}" "/mnt/${DRIVEDISKNAME}"
		fi
	else
		echo "Skipping $DRIVEDISKPATH, not a drive."
	fi

}

partmountcmd sda
partmountcmd sdb
partmountcmd sdc
partmountcmd sdd

systemctl restart smbd nmbd

EOLABC
chmod a+rwx "$MNTSCRIPT"

# Create mount service.
MNTSERVICE=/usr/lib/systemd/system/mounter.service
bash -c "cat >>$MNTSERVICE" <<'EOLABC'
[Unit]
Description=Mounter Script
After=network.target nmbd.service winbindd.service smbd.service

[Service]
ExecStart=/usr/local/bin/mounter.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOLABC

systemctl enable mounter.service

EOLXYZ
fi

cd $ARCHLIVEPATH

sudo bash <<EOF
$ARCHLIVEPATH/build.sh -v -o $OUTFOLDER -N $ISOFILENAME
rm -rf $ARCHLIVEPATH
if [ -d ${REPOFOLDER} ]; then
	rm -rf ${REPOFOLDER}
fi
chown $USER:users $OUTFOLDER/$ISOFILENAME*
chmod 777 $OUTFOLDER/$ISOFILENAME*
EOF

