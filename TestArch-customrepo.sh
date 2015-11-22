#!/bin/bash
set -e

# https://wiki.archlinux.org/index.php/DeveloperWiki:Building_in_a_Clean_Chroot
# https://wiki.archlinux.org/index.php/Building_32-bit_packages_on_a_64-bit_system

# Folder to build pacakges in.
BUILDFOLDER=/var/tmp
CHROOTBUILDFOLDER=${BUILDFOLDER}/chrootfldr
CHROOTBUILDX64FOLDER=${BUILDFOLDER}/chrootx64fldr

# Function for AUR build.
aur_build(){
	if [ -z "$1" ]; then
		echo "No paramter passed. Returning."
		return 0;
	else
		AURPKG=$1
	fi
	echo "Building $AURPKG."
	cd $BUILDFOLDER
	wget https://aur.archlinux.org/cgit/aur.git/snapshot/${AURPKG}.tar.gz -O ./${AURPKG}.tar.gz
	tar zxvf ${AURPKG}.tar.gz
	sudo chmod a+rwx -R ${AURPKG}
	cd ${AURPKG}
	x64_build
	i686_build
	sudo chmod a+rwx ${AURPKG}-*.pkg.tar.xz
	sudo chown 1000:100 ${AURPKG}-*.pkg.tar.xz
	sudo mv ${AURPKG}-*.pkg.tar.xz ../
	cd ..
	sudo rm -rf ${AURPKG}/
	sudo rm ${AURPKG}.tar.gz
}

# Function for i686 AUR build.
i686_build(){
	#~ sudo su nobody -s /bin/bash <<EOL
		#~ makechrootpkg -c -r $CHROOTBUILDFOLDER
#~ EOL
	makechrootpkg -c -r $CHROOTBUILDFOLDER
}

x64_build(){
	#~ sudo su nobody -s /bin/bash <<EOL
		#~ makepkg --noconfirm -c -f
#~ EOL
	#~ makepkg --noconfirm -c -f
	makechrootpkg -c -r $CHROOTBUILDX64FOLDER
}

x64_chroot(){
	set -u
	sudo cp /usr/share/devtools/pacman-extra.conf $CHROOTBUILDX64FOLDER/pacman.conf
	sudo sed -i 's/Architecture = .*/Architecture = x86_64/g' $CHROOTBUILDX64FOLDER/pacman.conf
	if [ -d $CHROOTBUILDX64FOLDER/root ]; then
		sudo rm -rf $CHROOTBUILDX64FOLDER/root
	fi
	sudo mkarchroot -C $CHROOTBUILDX64FOLDER/pacman.conf -M /usr/share/devtools/makepkg-x86_64.conf $CHROOTBUILDX64FOLDER/root base base-devel
	sudo arch-nspawn $CHROOTBUILDX64FOLDER/root pacman -Syyu
	set +u
}

i686_chroot(){
	set -u
	sudo cp /usr/share/devtools/pacman-extra.conf $CHROOTBUILDFOLDER/pacman.conf
	sudo sed -i 's/Architecture = .*/Architecture = i686/g' $CHROOTBUILDFOLDER/pacman.conf
	if [ -d $CHROOTBUILDFOLDER/root ]; then
		sudo rm -rf $CHROOTBUILDFOLDER/root
	fi
	sudo mkarchroot -C $CHROOTBUILDFOLDER/pacman.conf -M /usr/share/devtools/makepkg-i686.conf $CHROOTBUILDFOLDER/root base base-devel
	sudo arch-nspawn $CHROOTBUILDFOLDER/root pacman -Syyu
	set +u
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

clean_repo(){
	if [ -d ${REPOFOLDER} ]; then
		echo "Removing ${REPOFOLDER}."
		ls -la ${REPOFOLDER}/..
		ls -la ${REPOFOLDER}
		ls -la ${REPOFOLDER}/i686
		ls -la ${REPOFOLDER}/x86_64
		#rm -rf ${REPOFOLDER}
		sudo rm -rf ${CHROOTBUILDFOLDER}
		sudo rm -rf ${CHROOTBUILDX64FOLDER}
	fi
}


# Folder to store repo in.
REPONAME=localrepo
REPOFOLDER=${BUILDFOLDER}/${REPONAME}

clean_repo

if [ ! -d ${REPOFOLDER} ]; then
	echo "Creating ${REPOFOLDER}."
	sudo mkdir -p ${REPOFOLDER}
	echo "Creating ${REPOFOLDER}/i686."
	sudo mkdir -p ${REPOFOLDER}/i686
	echo "Creating ${REPOFOLDER}/x86_64."
	sudo mkdir -p ${REPOFOLDER}/x86_64
	sudo chmod 777 -R ${REPOFOLDER}
	echo "Creating ${CHROOTBUILDFOLDER}."
	sudo mkdir -p ${CHROOTBUILDFOLDER}
	sudo chmod 777 -R ${CHROOTBUILDFOLDER}
	echo "Creating ${CHROOTBUILDX64FOLDER}."
	sudo mkdir -p ${CHROOTBUILDX64FOLDER}
	sudo chmod 777 -R ${CHROOTBUILDX64FOLDER}
	i686_chroot
	x64_chroot
fi


# Build packages
aur_build debootstrap
aur_build apacman
aur_build rpm-org

build_repo

clean_repo

echo "Done".
