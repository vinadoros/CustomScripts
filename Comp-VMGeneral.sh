#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR=$SUDO_USER
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR=$USER
	else
		export USERNAMEVAR=$(id 1000 -un)
	fi
	USERGROUP=$(id 1000 -gn)
	USERHOME=/home/$USERNAMEVAR
fi

[ -z $VBOXGUEST ] && grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=1
[ -z $VBOXGUEST ] && ! grep -iq "VirtualBox" "/sys/devices/virtual/dmi/id/product_name" && VBOXGUEST=0
[ -z $QEMUGUEST ] && grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=1
[ -z $QEMUGUEST ] && ! grep -iq "QEMU" "/sys/devices/virtual/dmi/id/sys_vendor" && QEMUGUEST=0
[ -z $VMWGUEST ] && grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=1
[ -z $VMWGUEST ] && ! grep -iq "VMware" "/sys/devices/virtual/dmi/id/product_name" && VMWGUEST=0

set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Create and set /media folder permissions.
if [ ! -d /media ]; then
	mkdir -m 777 -p /media
fi
chmod a+rwx /media


if [ $QEMUGUEST = 1 ]; then

# 	# Set up ra script for auto resolution xrandr.
# 	echo "Creating /etc/systemd/system/ra@.service"
# 	cat >"/etc/systemd/system/ra@.service" <<EOL
# [Unit]
# Description=Display Resize script
# Requires=graphical.target
# After=systemd-user-sessions.service graphical.target
#
# [Service]
# Type=simple
# Environment="DISPLAY=:%i" "XAUTHORITY=$USERHOME/.Xauthority"
# ExecStart=/usr/local/bin/ra.sh
# Restart=on-failure
#
# [Install]
# WantedBy=graphical.target
# EOL
# 	systemctl daemon-reload
# 	systemctl enable ra@0.service

# Create user systemd service for ra.
user_systemd_service "ra.service" <<EOL
[Unit]
Description=Display Resize script

[Service]
Type=simple
ExecStart=/usr/local/bin/ra.sh
Restart=on-failure
RestartSec=5s
TimeoutStopSec=7s

[Install]
WantedBy=default.target
EOL

	multilinereplace "/usr/local/bin/ra.sh" <<'EOL'
#!/bin/bash

loopra () {
	sleep 5
	xhost +localhost
	while true; do
		sleep 1
		env DISPLAY=$DISPLAY xrandr --output Virtual-0 --auto
	done
}

case "\$1" in
  "pre")
	echo "Running pre-case for ra script."
    ;;
  "post")
	echo "Running post-case for ra script."
    ;;
  *)
  	echo "Running for ra script."
	loopra
    ;;
esac
EOL

	#~ echo "Creating ra.desktop."
	#~ bash -c "cat >/etc/xdg/autostart/ra.desktop" <<'EOL'
#~ [Desktop Entry]
#~ Name=ra
#~ Exec=/usr/local/bin/ra
#~ Type=Application
#~ Terminal=false
#~ StartupNotify=false
#~ X-GNOME-Autostart-enabled=true
#~ EOL
	#~ chmod 644 /etc/xdg/autostart/ra.desktop


	# Set up virtio filesystem mounts.
	if ! grep -iq "virtio" /etc/fstab; then
		echo "Editing fstab for virtio filesystem."
		blank=$(tail -1 /etc/fstab)
		if [ "$blank" != '' ]; then
			echo "" | sudo tee -a /etc/fstab
		fi
		mkdir -m 777 -p /media/sf_Storage
		echo "Storage /media/sf_Storage 9p rw,defaults,trans=virtio,version=9p2000.L,noauto,x-systemd.automount 0 0" | sudo tee -a /etc/fstab
		mkdir -m 777 -p /media/sf_root
		echo "root /media/sf_root 9p rw,defaults,trans=virtio,version=9p2000.L,noauto,x-systemd.automount 0 0" | sudo tee -a /etc/fstab
	fi

fi
