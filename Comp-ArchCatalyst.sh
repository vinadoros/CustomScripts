#!/bin/bash

set +eu

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

echo "You are currently using the following module:"
lsmod | grep fglrx
lsmod | grep radeon

echo "Note: This script does not halt upon detecting an error."

while true; do
    read -p "Remove or Enable Catalyst? (r for remove / e for Enable / q for quit)" ROOTQUESTION
    case $ROOTQUESTION in
    
    [Rr]* ) 
    echo "You asked to remove catalyst."
    
    sudo pacman -Syu
    sudo systemctl disable catalyst-hook
    sudo systemctl disable atieventsd
    sudo sed -i '/blacklist radeon/d' /etc/modprobe.d/modprobe.conf
    sudo rm /etc/modules-load.d/catalyst.conf
    sudo rm /etc/profile.d/catalyst.sh
    sudo rm /etc/profile.d/lib32-catalyst.sh
    sudo mv /etc/X11/xorg.conf /etc/X11/xorg.conf.atibak
    
	# Remove catalyst
    sudo pacman -Rdd --noconfirm catalyst-hook 
    sudo pacman -Rdd --noconfirm catalyst-utils 
    sudo pacman -Rdd --noconfirm lib32-catalyst-utils 
    sudo pacman -Rdd --noconfirm lib32-catalyst-libgl 
    sudo pacman -Rdd --noconfirm catalyst-libgl 
    sudo pacman -Rdd --noconfirm opencl-catalyst 
    sudo pacman -R --noconfirm acpid
    
    # Install free drivers
    sudo pacman -S --needed --noconfirm xf86-video-ati xf86-video-intel xf86-video-nouveau lib32-mesa-dri lib32-mesa-libgl mesa-dri mesa-vdpau mesa-libgl ocl-icd lib32-ocl-icd
    
    sudo sed -i 's/GRUB_CMDLINE_LINUX=\"nomodeset\"/GRUB_CMDLINE_LINUX=\"\"/g' /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    
    echo "Catalyst removed."    
	break;;
	
	
	
	
	
	[Ee]* ) 
	echo "You asked to enable catalyst."
	
	
	if ! grep -Fq "[catalyst]" /etc/pacman.conf; then
        echo "Adding catalyst to pacman.conf"
        while read line
        do
        echo $line | grep -q "#\[testing\]"
        [ $? -eq 0 ] && cat <<"EOL"
        
[catalyst]
#Server = http://catalyst.wirephire.com/repo/catalyst/$arch
## Mirrors, if the primary server does not work or is too slow:
#Server = http://70.239.162.206/catalyst-mirror/repo/catalyst/$arch
Server = http://mirror.rts-informatique.fr/archlinux-catalyst/repo/catalyst/$arch
#Server = http://mirror.hactar.bz/Vi0L0/catalyst/$arch

EOL
        echo $line
        done < /etc/pacman.conf | cat > ~/pacman.conf.new
    
        if grep -Fq "[catalyst]" ~/pacman.conf.new; then
            echo "Replacing pacman.conf"
            sudo rm /etc/pacman.conf
            sudo mv ~/pacman.conf.new /etc/pacman.conf
        else
            echo "Catalyst repo not found in pacman.conf.new. Exiting."
            exit 1;
        fi
        
		sudo pacman-key -r 653C3094
		sudo pacman-key --lsign-key 653C3094
        
    fi
    
	if ! grep -Fq "[catalyst]" /etc/pacman.conf; then
        echo "Catalyst repo not found in pacman.conf. Exiting."
        exit 1;
    fi
	
	pacman -Syyu --needed --noconfirm
	
	
	# Remove free drivers
    sudo pacman -Rdd --noconfirm xf86-video-ati
    sudo pacman -Rdd --noconfirm xf86-video-intel
    sudo pacman -Rdd --noconfirm xf86-video-nouveau
    sudo pacman -Rdd --noconfirm lib32-mesa-dri 
    sudo pacman -Rdd --noconfirm lib32-mesa-libgl
    sudo pacman -Rdd --noconfirm mesa-dri
    sudo pacman -Rdd --noconfirm mesa-vdpau
    sudo pacman -Rdd --noconfirm mesa-libgl
    sudo pacman -Rdd --noconfirm ocl-icd
    sudo pacman -Rdd --noconfirm lib32-ocl-icd
    
    # Re-install catalyst.
    sudo pacman -S --needed qt4 catalyst-hook catalyst-utils lib32-catalyst-utils lib32-catalyst-libgl catalyst-libgl opencl-catalyst acpid
    
    if [ ! -f /etc/modprobe.d/modprobe.conf ] || ! grep -Fq "blacklist radeon" /etc/modprobe.d/modprobe.conf; then
        sudo systemctl enable catalyst-hook
        sudo systemctl start catalyst-hook
        sudo systemctl enable atieventsd
        sudo systemctl start atieventsd
        
        if [ -f /etc/X11/xorg.conf.atibak ]; then
        	#Retrieve existing Xorg backup if it exists.
			sudo mv /etc/X11/xorg.conf.atibak /etc/X11/xorg.conf
		else
			#Setup xorg.conf using aticonfig.
			sudo aticonfig --initial=dual-head
		fi
        
        #Disable kernel mode setting.
        sudo sed -i 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"nomodeset\"/g' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        
        #Need to blacklist the radeon driver
        echo 'blacklist radeon' | sudo tee -a /etc/modprobe.d/modprobe.conf
    fi
    echo "Catalyst Installed. Please reboot the system."
	
	break;;
	
	[Qq]* ) 
	echo "You asked to quit."
	break;;
	
	* ) echo "Please input r (remove catalyst), e (enable catalyst), or q (quit).";;
    esac
done
