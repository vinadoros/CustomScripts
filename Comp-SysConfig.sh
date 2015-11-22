#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

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

[ -z "$MACHINEARCH" ] && MACHINEARCH="$(uname -m)"

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi


# Set computer to not sleep on lid close
if ! grep -Fxq "HandleLidSwitch=lock" /etc/systemd/logind.conf; then
    echo 'HandleLidSwitch=lock' | sudo tee -a /etc/systemd/logind.conf
fi

#Xorg fix for Joysticks
if [ ! -d /etc/X11/xorg.conf.d/ ]; then
	mkdir -p /etc/X11/xorg.conf.d/
	chmod a+r /etc/X11/xorg.conf.d/
fi
if [ ! -f /etc/X11/xorg.conf.d/50-joystick.conf ]; then
	bash -c "cat >>/etc/X11/xorg.conf.d/50-joystick.conf" <<'EOL'
Section "InputClass"
        Identifier "joystick catchall"
        MatchIsJoystick "on"
        MatchDevicePath "/dev/input/event*"
        Driver "joystick"
        Option "StartKeysEnabled" "False"       #Disable mouse
        Option "StartMouseEnabled" "False"      #support
EndSection
EOL
fi

# Pulseaudio gdm fix
# http://www.debuntu.org/how-to-disable-pulseaudio-and-sound-in-gdm/
# https://bbs.archlinux.org/viewtopic.php?id=202915
if [[ $(type -P gdm) || $(type -P gdm3) && -f /etc/pulse/default.pa ]]; then
	echo "Executing gdm pulseaudio fix."
	set +eu
	if type -P gdm3; then
		GDMUID="$(id -u Debian-gdm)"
		GDMGID="$(id -g Debian-gdm)"
		GDMPATH="/var/lib/gdm3"
	elif type -P gdm; then
		GDMUID="$(id -u gdm)"
		GDMGID="$(id -g gdm)"
		GDMPATH="/var/lib/gdm"
	fi
	set -eu

	if [ ! -d "$GDMPATH/.config/pulse/" ]; then
		mkdir -p "$GDMPATH/.config/pulse/"
	fi
	
	#~ bash -c "cat >$GDMPATH/.config/pulse/client.conf" <<EOL
#~ autospawn = no
#~ daemon-binary = /bin/true
#~ EOL

	cp /etc/pulse/default.pa "$GDMPATH/.config/pulse/default.pa"
	sed -i '/^load-module .*/s/^/#/g' "$GDMPATH/.config/pulse/default.pa"

	chown -R $GDMUID:$GDMGID "$GDMPATH/.config/pulse/"
fi

# Enable pulseaudio flat volumes
if ! grep -iq "^flat-volumes=no" /etc/pulse/daemon.conf; then
	echo 'flat-volumes=no' >> /etc/pulse/daemon.conf
fi

# Modify journald log size
# https://unix.stackexchange.com/questions/139513/how-to-clear-journalctl
if [ -f /etc/systemd/journald.conf ]; then
	# Remove commented lines
	sed -i '/^#Compress=.*/s/^#//g' /etc/systemd/journald.conf
	sed -i '/^#SystemMaxUse=.*/s/^#//g' /etc/systemd/journald.conf
	# Edit uncommented lines
	sed -i 's/^Compress=.*/Compress=yes/g' /etc/systemd/journald.conf
	sed -i 's/^SystemMaxUse=.*/SystemMaxUse=300M/g' /etc/systemd/journald.conf
	# Vacuum existing logs
	journalctl --vacuum-size=295M
	# Vacuum all logs
	#journalctl --vacuum-time=1s
fi
# Disable copy-on-write for journal logs
if [ -d /var/log/journal ]; then
	chattr -R +C /var/log/journal/
fi

# SSH copy key script
SSHKEYSCRIPT=/usr/local/bin/sscp
echo "Creating $SSHKEYSCRIPT"
bash -c "cat >$SSHKEYSCRIPT" <<'EOL'
#!/bin/bash

if [ -z "$@" ]; then
	echo "Enter a valid ssh host."
	exit 1;
fi

set -eu

if [ ! -f ~/.ssh/id_rsa.pub ]; then
	ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)"
fi

cat ~/.ssh/id_rsa.pub | ssh "$@" "mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 600 ~/.ssh/authorized_keys"
echo "Script completed successfully."
EOL
chmod a+rwx "$SSHKEYSCRIPT"


if [ "${MACHINEARCH}" != "armv7l" ]; then
	echo "Install x86 specific tweaks."
	
	# Edit grub timeout
	if [ -f /etc/default/grub ]; then
		sed -i 's/GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/g' /etc/default/grub
		if [ $(type -P update-grub) ]; then
			update-grub
		else
			grub-mkconfig -o /boot/grub/grub.cfg
		fi
	fi

elif [ "${MACHINEARCH}" = "armv7l" ]; then
	echo "Install arm specific tweaks."
	
fi


if [ "${MACHINEARCH}" != "armv7l" ]; then
###############################################################################
#######################        Power-Saving Stuff      ########################
###############################################################################

#Enable audio powersaving
[ -f /etc/modprobe.d/audio_powersave.conf ] && rm /etc/modprobe.d/audio_powersave.conf
#~ if [ ! -f /etc/modprobe.d/audio_powersave.conf ]; then
	#~ echo "Creating /etc/modprobe.d/audio_powersave.conf"
	#~ bash -c "cat >>/etc/modprobe.d/audio_powersave.conf" <<EOL
#~ options snd_hda_intel power_save=1
#~ options snd_ac97_codec power_save=1
#~ EOL
#~ fi
	
[ -f /etc/udev/rules.d/70-disable_wol.rules ] && rm /etc/udev/rules.d/70-disable_wol.rules
#~ #Enable ethernet powersaving (turn off Wake-on-Lan)
#~ if [ ! -f /etc/udev/rules.d/70-disable_wol.rules ]; then
	#~ echo "Creating /etc/udev/rules.d/70-disable_wol.rules"
	#~ bash -c "cat >>/etc/udev/rules.d/70-disable_wol.rules" <<EOL
#~ ACTION=="add", SUBSYSTEM=="net", KERNEL=="en*", RUN+="/usr/bin/ethtool -s %k wol d"
#~ ACTION=="add", SUBSYSTEM=="net", KERNEL=="eth*", RUN+="/usr/bin/ethtool -s %k wol d"
#~ EOL
#~ fi

[ -f /etc/udev/rules.d/70-wifi-powersave.rules ] && rm /etc/udev/rules.d/70-wifi-powersave.rules
#~ #Enable wifi powersaving
#~ if [ ! -f /etc/udev/rules.d/70-wifi-powersave.rules ]; then
	#~ echo "Creating /etc/udev/rules.d/70-wifi-powersave.rules"
	#~ bash -c "cat >>/etc/udev/rules.d/70-wifi-powersave.rules" <<EOL
#~ ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*", RUN+="/usr/bin/iw dev %k set power_save on"
#~ ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/usr/bin/iw dev %k set power_save on"
#~ EOL
#~ fi

#Disable Watchdog
[ -f /etc/sysctl.d/disable_watchdog.conf ] && rm /etc/sysctl.d/disable_watchdog.conf
#~ if [ ! -f /etc/sysctl.d/disable_watchdog.conf ]; then
	#~ echo "Creating /etc/sysctl.d/disable_watchdog.conf"
	#~ bash -c "cat >>/etc/sysctl.d/disable_watchdog.conf" <<EOL
#~ kernel.nmi_watchdog = 0
#~ EOL
#~ fi

#Writeback Time
[ -f /etc/sysctl.d/dirty.conf ] && rm /etc/sysctl.d/dirty.conf
#~ if [ ! -f /etc/sysctl.d/dirty.conf ]; then
	#~ echo "Creating /etc/sysctl.d/dirty.conf"
	#~ bash -c "cat >>/etc/sysctl.d/dirty.conf" <<EOL
#~ vm.dirty_writeback_centisecs = 1500
#~ EOL
#~ fi

#PCI Runtime Power Management
[ -f /etc/udev/rules.d/pci_pm.rules ] && rm /etc/udev/rules.d/pci_pm.rules
#~ if [ ! -f /etc/udev/rules.d/pci_pm.rules ]; then
	#~ echo "Creating /etc/udev/rules.d/pci_pm.rules"
	#~ bash -c "cat >>/etc/udev/rules.d/pci_pm.rules" <<EOL
#~ ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
#~ EOL
#~ fi

#USB autosuspend
[ -f /etc/modprobe.d/modprobe.conf ] && rm /etc/modprobe.d/modprobe.conf
#~ if [ ! -f /etc/modprobe.d/modprobe.conf ]; then
	#~ echo "Creating /etc/modprobe.d/modprobe.conf"
	#~ bash -c "cat >>/etc/modprobe.d/modprobe.conf" <<EOL
#~ options usbcore autosuspend=2
#~ EOL
#~ fi

fi
