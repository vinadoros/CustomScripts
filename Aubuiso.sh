#!/usr/bin/env bash

# First, set up the build tools and workspace.
# The scripts require that you work in /build

apt-get install -y genisoimage syslinux-utils # tools for generate ISO image
apt-get install -y memtest86+ syslinux syslinux-themes-ubuntu-xenial gfxboot-theme-ubuntu

# apt-get install -y livecd-rootfs
lb clean
cp -a /usr/share/livecd-rootfs/live-build/auto .
sed -i 's@#! /bin/sh@#! /bin/sh -x@g' ./auto/config ./auto/build

# All the hard work is done with live-build (lb command)
# and we have to configure it with environment variables

export SUITE=zesty
export ARCH=amd64
export PROJECT=base
export MIRROR=http://archive.ubuntu.com/ubuntu/
export mirror_url=http://archive.ubuntu.com/ubuntu/
export BINARYFORMAT=iso-hybrid
export LB_SYSLINUX_THEME=ubuntu-xenial

# Now we can have live-build set up the workspace
lb config --initramfs-compression=gzip

# Add repositories
mkdir -p ./config/archives
cat > ./config/archives/your-repository.list.binary <<EOF
deb http://us.archive.ubuntu.com/ubuntu $SUITE main restricted universe multiverse
EOF
cat > ./config/archives/your-repository.list.chroot <<EOF
deb http://us.archive.ubuntu.com/ubuntu $SUITE main restricted universe multiverse
EOF

# Add package list
mkdir -p ./config/package-lists
cat > ./config/package-lists/custom.list.chroot <<'EOF'
# System stuff
grub-efi-amd64
shim-signed
# Desktop utils
mate-desktop-environment
caja-open-terminal
caja-gksu
dconf-editor
gnome-keyring
dconf-cli
leafpad
midori
gvfs
avahi-daemon
avahi-discover
# CLI Utilities
sudo
ssh
tmux
nano
curl
rsync
less
iotop
git
# Provides the mkpasswd utility
whois
# Recovery and Backup utils
clonezilla
gparted
fsarchiver
gnome-disk-utility
btrfs-tools
f2fs-tools
xfsprogs
dmraid
mdadm
chntpw
debootstrap
# VM Utilities
dkms
spice-vdagent
qemu-guest-agent
open-vm-tools
open-vm-tools-dkms
# open-vm-tools-desktop
virtualbox-guest-utils
virtualbox-guest-dkms
EOF

mkdir -p ./config/hooks
# Add binary script
cat > ./config/hooks/custom.hook.binary <<'EOL'
#!/bin/bash -x
# Fix kernel and initrd locations.
cp -a ./chroot/boot/vmlinuz-*-generic ./binary/casper/vmlinuz
cp -a ./chroot/boot/initrd.img-*-generic ./binary/casper/initrd.lz
EOL
# Add chroot script
cat > ./config/hooks/custom.hook.chroot <<'EOFXYZ'
#!/bin/bash -x
# Modify ssh config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config

# Install CustomScripts
git clone "https://github.com/vinadoros/CustomScripts.git" "/CustomScripts"

# --- BEGIN Update CustomScripts on startup ---

cat >/etc/systemd/system/updatecs.service <<EOL
[Unit]
Description=updatecs service
Requires=network-online.target
After=network.target nss-lookup.target network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -c "cd /CustomScripts; git pull"
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

# Set computer to not sleep on lid close
if ! grep -Fxq "HandleLidSwitch=lock" /etc/systemd/logind.conf; then
	echo 'HandleLidSwitch=lock' >> /etc/systemd/logind.conf
fi

# Add CustomScripts to path
SCRIPTBASENAME="/CustomScripts"
if ! grep "$SCRIPTBASENAME" /root/.bashrc; then
	cat >>/root/.bashrc <<EOLBASH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME
fi
EOLBASH
fi
if ! grep "$SCRIPTBASENAME" /home/ubuntu/.bashrc; then
	cat >>/home/ubuntu/.bashrc <<EOLBASH

if [ -d $SCRIPTBASENAME ]; then
	export PATH=\$PATH:$SCRIPTBASENAME:/sbin:/usr/sbin
fi
EOLBASH
fi

# Remove apps
apt-get remove -y ubiquity ubiquity-casper
apt-get remove -y ubuntu-mate-welcome

# Set root password
passwd -u root
echo "root:asdf" | chpasswd
EOFXYZ


# Start the build
lb build
