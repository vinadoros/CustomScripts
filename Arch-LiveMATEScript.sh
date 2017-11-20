#!/bin/bash

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

if [ ! -z "$1" ]; then
	INPUTFOLDER="$(readlink -f $1)"
fi
if [ ! -z "$2" ]; then
	OUTFOLDER="$(readlink -f $2)"
fi

# Set location to perform build and store ISO.
if [ -d "$INPUTFOLDER" ]; then
	ARCHLIVEPATH=$INPUTFOLDER/archlive
else
	ARCHLIVEPATH=$PWD/archlive
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
# if ! grep -Fq "copytoram" $ARCHLIVEPATH/syslinux/archiso.cfg; then
# 	sed -i '/APPEND/ s|$| copytoram=y |' $ARCHLIVEPATH/syslinux/archiso.cfg
# fi

# Copy script folder to iso root
#~ cp -r "$SCRIPTDIR" "$ARCHLIVEPATH/airootfs/"
git clone "https://github.com/vinadoros/CustomScripts.git" "$ARCHLIVEPATH/airootfs/CustomScripts"
#~ SCRIPTBASENAME="$(basename $SCRIPTDIR)"
SCRIPTBASENAME="CustomScripts"

# Set syslinux timeout
if ! grep -iq "^TIMEOUT" "$ARCHLIVEPATH/syslinux/archiso_sys.cfg"; then
	echo "TIMEOUT 30" >> "$ARCHLIVEPATH/syslinux/archiso_sys.cfg"
	echo "TOTALTIMEOUT 600" >> "$ARCHLIVEPATH/syslinux/archiso_sys.cfg"
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
spice-vdagent

# Desktop stuff
lxdm
xorg-server
xorg-drivers
mesa-libgl
mesa-demos
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
mate

# Mate Extra tools
atril
caja-gksu
caja-open-terminal
engrampa
eom
galculator
mate-applets
mate-power-manager
mate-screensaver
mate-system-monitor
mate-terminal
mate-utils
pluma
mate-icon-theme-faenza
ttf-dejavu
ttf-liberation
ttf-roboto
noto-fonts
EOL

sudo bash -c "cat >>$ARCHLIVEPATH/airootfs/root/customize_airootfs.sh" <<EOLXYZ

set -x
SCRIPTBASENAME="/$SCRIPTBASENAME"

EOLXYZ

sudo bash -c "cat >>$ARCHLIVEPATH/airootfs/root/customize_airootfs.sh" <<'EOLXYZ'

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
systemctl enable spice-vdagentd

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
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

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

# Run MATE Settings script on desktop startup.
cat >"/etc/xdg/autostart/matesettings.desktop" <<"EOL"
[Desktop Entry]
Name=MATE Settings Script
Exec=/CustomScripts/Dset.sh
Terminal=false
Type=Application
EOL

# Autoset resolution
cat >"/etc/xdg/autostart/ra.desktop" <<"EOL"
[Desktop Entry]
Name=Autoresize Resolution
Exec=/usr/local/bin/ra.sh
Terminal=false
Type=Application
EOL
cat >"/usr/local/bin/ra.sh" <<'EOL'
#!/bin/bash
while true; do
	sleep 5
	if [ -z $DISPLAY ]; then
		echo "Display variable not set. Exiting."
		exit 1;
	fi
	xhost +localhost
	# Detect the display output from xrandr.
	RADISPLAYS=$(xrandr --listmonitors | awk '{print $4}')
	while true; do
		sleep 1
		# Loop through every detected display and autoset them.
		for disp in ${RADISPLAYS[@]}; do
			xrandr --output $disp --auto
		done
	done
done
EOL
chmod a+rwx /usr/local/bin/ra.sh

# Add CustomScripts to path
if ! grep "$SCRIPTBASENAME" /root/.zshrc; then
	cat >>/root/.zshrc <<EOLZSH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME
fi
EOLZSH
fi

EOLXYZ

cd "$ARCHLIVEPATH"

sudo bash <<EOF
"$ARCHLIVEPATH"/build.sh -v -o "$OUTFOLDER" -N "$ISOFILENAME"
if [ -d "$ARCHLIVEPATH" ]; then
	echo "Removing $ARCHLIVEPATH"
	rm -rf "$ARCHLIVEPATH"
fi
chmod a+rwx "$OUTFOLDER/$ISOFILENAME"*
EOF
