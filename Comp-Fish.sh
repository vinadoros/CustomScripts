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
type -t grepadd >> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

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

# Enable error halting.
set -eu

# Configure fish
FISHPATH="$(which fish)"
if [[ $SHELL != *"fish"* ]]; then
	echo "Configuring fish shell."
	until chsh -s $FISHPATH $USERNAMEVAR
		do echo "Try again in 2 seconds."
		sleep 2
		echo "Enter password for changing the shell."
	done
	chsh -s $FISHPATH
fi

if [ ! -d $USERHOME/.config/fish/ ]; then
	mkdir -p $USERHOME/.config/fish/
	chown -R ${USERNAMEVAR}:${USERGROUP} $USERHOME/.config
fi

# Set User fish config
USERFISH="$USERHOME/.config/fish/config.fish"
# Set root fish config
ROOTFISH="/root/.config/fish/config.fish"

# Replace config.fish
if [ -f "$USERFISH" ]; then
	rm "$USERFISH"
fi
if [ -f "$ROOTFISH" ]; then
	rm "$ROOTFISH"
fi

grepadd "set CUSTOMSCRIPTPATH \"$SCRIPTDIR\"" "$USERFISH"

multilineadd "$USERFISH" "function stop" <<'EOL'
set -gx EDITOR nano
if [ (uname -m) != "armv7l" ]
	set -gx XZ_OPT "-9T0"
end
if timeout 3 test -d "$CUSTOMSCRIPTPATH"
	set -gx PATH $PATH "$CUSTOMSCRIPTPATH"
end
function sl
	xhost +localhost >> /dev/null
	env DISPLAY=$DISPLAY sudo fish
end
function pc
	set -x EXISTPATH (pwd)
	cd "$CUSTOMSCRIPTPATH"
	git fetch --all
	git diff
	git status
	if not test -z $argv
		git add -A
		git commit -m "$argv"
		git pull
		git push
	else
		echo "No commit message entered. Exiting."
	end
	git pull
	cd "$EXISTPATH"
	set -e EXISTPATH
end
function sst
	ssh -t $argv "tmux attach; or tmux new"
end
function start
	echo "Starting systemd service $argv."
	sudo systemctl start $argv
	sudo systemctl status -l $argv
end
function stop
	echo "Stopping systemd service $argv."
	sudo systemctl stop $argv
	sudo systemctl status -l $argv
end
function en
	echo "Enabling systemd service $argv."
	sudo systemctl enable $argv
	sudo systemctl status -l $argv
end
function dis
	echo "Disabling systemd service $argv."
	sudo systemctl disable $argv
	sudo systemctl status -l $argv
end
function res
	echo "Restarting systemd service $argv."
	sudo systemctl restart $argv
	sudo systemctl status -l $argv
end
function st
	echo "Getting status for systemd service $argv."
	sudo systemctl status -l $argv
end
function dr
	echo "Executing systemd daemon-reload."
	sudo systemctl daemon-reload
end
EOL

chown -R $USERNAMEVAR:$USERGROUP $USERHOME/.config/fish


if [[ "$(id -u)" == "0" && ! -d /root/.config/fish/ ]]; then
	mkdir -p /root/.config/fish/
fi

if [ "$(id -u)" == "0" ]; then

	grepadd "set CUSTOMSCRIPTPATH \"$SCRIPTDIR\"" "$ROOTFISH"

	multilineadd "$ROOTFISH" "function stop" <<'EOL'
set -gx EDITOR nano
if [ (uname -m) != "armv7l" ]
	set -gx XZ_OPT "-9T0"
end
if timeout 3 test -d "$CUSTOMSCRIPTPATH"
	set -gx PATH $PATH "$CUSTOMSCRIPTPATH"
end
function start
	echo "Starting systemd service $argv."
	systemctl start $argv
	systemctl status -l $argv
end
function stop
	echo "Stopping systemd service $argv."
	systemctl stop $argv
	systemctl status -l $argv
end
function en
	echo "Enabling systemd service $argv."
	systemctl enable $argv
	systemctl status -l $argv
end
function dis
	echo "Disabling systemd service $argv."
	systemctl disable $argv
	systemctl status -l $argv
end
function res
	echo "Restarting systemd service $argv."
	systemctl restart $argv
	systemctl status -l $argv
end
function st
	echo "Getting status for systemd service $argv."
	systemctl status -l $argv
end
function dr
	echo "Executing systemd daemon-reload."
	systemctl daemon-reload
end
EOL
fi

if [[ $(type -P pacman) ]]; then

	echo "Appending pacman to $USERFISH."
	cat >>"$USERFISH" <<'EOL'
function pmi
	echo "Installing $argv or updating using pacman."
	sudo pacman -Syu --needed $argv
end
function ami
	echo "Installing $argv using apacman."
	sudo apacman -S --needed --ignorearch $argv
end
function amin
	echo "Installing $argv using apacman."
	sudo apacman -S --needed --noconfirm --ignorearch $argv
end
function up
	echo "Starting full system update using apacman."
	sudo apacman -Syu --noconfirm --ignorearch
end
function rmd
	echo "Removing /var/lib/pacman/db.lck."
	sudo rm /var/lib/pacman/db.lck
end
function cln
	echo "Removing (supposedly) uneeded packages."
	pacman -Qdtq | sudo pacman -Rs -
end
function rmv
	echo "Removing $argv and dependancies using pacman."
	sudo pacman -Rsn $argv
end
function psc
	echo "Searching for $argv using apacman."
	apacman -Ss $argv
end
function gitup
	echo "Upgrading git packages from AUR."
	sudo apacman -S --skipcache --noconfirm --ignorearch (pacman -Qq | grep -i "\-git")
end
EOL

	if [ "$(id -u)" == "0" ]; then
		echo "Appending pacman to $ROOTFISH."
		cat >>"$ROOTFISH" <<'EOL'
function pmi
	echo "Installing $argv or updating using pacman."
	pacman -Syu --needed $argv
end
function ami
	echo "Installing $argv using apacman."
	apacman -S --needed --ignorearch $argv
end
function amin
	echo "Installing $argv using apacman."
	apacman -S --needed --noconfirm --ignorearch $argv
end
function up
	echo "Starting full system update using apacman."
	apacman -Syu --noconfirm --ignorearch
end
function rmd
	echo "Removing /var/lib/pacman/db.lck."
	rm /var/lib/pacman/db.lck
end
function cln
	echo "Removing (supposedly) uneeded packages."
	pacman -Qdtq | pacman -Rs -
end
function rmv
	echo "Removing $argv and dependancies using pacman."
	pacman -Rsn $argv
end
function psc
	echo "Searching for $argv using apacman."
	apacman -Ss $argv
end
function gitup
	echo "Upgrading git packages from AUR."
	apacman -S --skipcache --noconfirm --ignorearch (pacman -Qq | grep -i "\-git")
end
EOL
	fi

elif [[ $(type -P apt-get) ]]; then

	echo "Appending apt to $USERFISH."
	cat >>"$USERFISH" <<'EOL'
set -gx PATH $PATH /usr/local/sbin /usr/sbin /sbin
function agi
	echo "Installing $argv."
	sudo apt-get install $argv
end
function agiy
	echo "Installing $argv."
	sudo apt-get install -y $argv
end
function afix
	echo "Running apt-get -f install."
	sudo apt-get -f install
end
function agr
	echo "Removing $argv."
	sudo apt-get --purge remove $argv
end
function agu
	echo "Updating Repos."
	sudo apt-get update
end
function acs
	echo "Searching for $argv."
	apt-cache search $argv
end
function acp
	echo "Policy for $argv."
	apt-cache policy $argv
end
function agup
	echo "Upgrading system."
	sudo apt-get upgrade
end
function agdup
	echo "Dist-upgrading system."
	sudo apt-get dist-upgrade
end
function aar
	echo "Auto-removing packages."
	sudo apt-get autoremove --purge
end
function up
	echo "Updating and Dist-upgrading system."
	sudo apt-get update
	sudo apt-get dist-upgrade
end
function ark
	echo "Removing old kernels."
	sudo apt-get purge (ls -tr /boot/vmlinuz-* | head -n -2 | grep -v (uname -r) | cut -d- -f2- | awk '{print "linux-image-" $0 "\nlinux-headers-" $0}')
end
EOL

	if [ "$(id -u)" == "0" ]; then
		echo "Appending apt to $ROOTFISH."
		cat >>"$ROOTFISH" <<'EOL'
set -gx PATH $PATH /usr/local/sbin /usr/sbin /sbin
function agi
	echo "Installing $argv."
	apt-get install $argv
end
function agiy
	echo "Installing $argv."
	apt-get install -y $argv
end
function afix
	echo "Running apt-get -f install."
	apt-get -f install
end
function agr
	echo "Removing $argv."
	apt-get --purge remove $argv
end
function agu
	echo "Updating Repos."
	apt-get update
end
function acs
	echo "Searching for $argv."
	apt-cache search $argv
end
function acp
	echo "Policy for $argv."
	apt-cache policy $argv
end
function agup
	echo "Upgrading system."
	apt-get upgrade
end
function agdup
	echo "Dist-upgrading system."
	apt-get dist-upgrade
end
function aar
	echo "Auto-removing packages."
	apt-get autoremove --purge
end
function up
	echo "Updating and Dist-upgrading system."
	apt-get update
	apt-get dist-upgrade
end
function ark
	echo "Removing old kernels."
	apt-get purge (ls -tr /boot/vmlinuz-* | head -n -2 | grep -v (uname -r) | cut -d- -f2- | awk '{print "linux-image-" $0 "\nlinux-headers-" $0}')
end
EOL
	fi

elif [[ $(type -P dnf) ]]; then

	echo "Appending dnf to $USERFISH."
	cat >>"$USERFISH" <<'EOL'
function di
	echo "Installing $argv."
	sudo dnf install $argv
end
function diy
	echo "Installing $argv."
	sudo dnf install -y $argv
end
function rmv
	echo "Removing $argv."
	sudo dnf remove $argv
end
function ds
	echo "Searching for $argv."
	sudo dnf search $argv
	echo "Searching installed packages for $argv."
	dnf list installed | grep -i $argv
end
function dar
	echo "Auto-removing packages."
	sudo dnf autoremove
end
function up
	echo "Updating system."
	sudo dnf update -y
end
EOL

	if [ "$(id -u)" == "0" ]; then
		echo "Appending dnf to $ROOTFISH."
		cat >>"$ROOTFISH" <<'EOL'
function di
	echo "Installing $argv."
	dnf install $argv
end
function diy
	echo "Installing $argv."
	dnf install -y $argv
end
function rmv
	echo "Removing $argv."
	dnf remove $argv
end
function ds
	echo "Searching for $argv."
	dnf search $argv
	echo "Searching installed packages for $argv."
	dnf list installed | grep -i $argv
end
function dar
	echo "Auto-removing packages."
	dnf autoremove
end
function up
	echo "Updating system."
	dnf update -y
end
EOL
	fi


fi
