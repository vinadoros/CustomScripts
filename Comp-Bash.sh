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

# Replace bashrc
if [ -f "/etc/skel/.bashrc" ]; then
	cp /etc/skel/.bashrc "$USERHOME/"
	chown ${USERNAMEVAR}:${USERGROUP} "$USERHOME/.bashrc"
fi

grepadd "CUSTOMSCRIPTPATH=\"$SCRIPTDIR\"" "$USERHOME/.bashrc"

multilineadd "$USERHOME/.bashrc" "function stop" <<'EOL'
export EDITOR=nano
export XZ_OPT="-9T0"
alias la='ls -lah --color=auto'
if timeout 3 test -d "$CUSTOMSCRIPTPATH" && ! echo $PATH | grep -iq "$CUSTOMSCRIPTPATH"; then
	export PATH=$PATH:$CUSTOMSCRIPTPATH
fi
function pc () {
	EXISTPATH="$(pwd)"
	cd "$CUSTOMSCRIPTPATH"
	git fetch --all
	git diff
	git status
	if [ ! -z "$1" ]; then
		git add -A
		git commit -m "$1"
		git pull
		git push
	else
		echo "No commit message entered. Exiting."
	fi
	git pull
	cd "$EXISTPATH"
	unset EXISTPATH
}
function start () {
	echo "Starting systemd service $@."
	sudo systemctl start "$@"
	sudo systemctl status -l "$@"
}
function stop () {
	echo "Stopping systemd service $@."
	sudo systemctl stop "$@"
	sudo systemctl status -l "$@"
}
function en () {
	echo "Enabling systemd service $@."
	sudo systemctl enable "$@"
	sudo systemctl status -l "$@"
}
function dis () {
	echo "Disabling systemd service $@."
	sudo systemctl disable "$@"
	sudo systemctl status -l "$@"
}
function res () {
	echo "Restarting systemd service $@."
	sudo systemctl restart "$@"
	sudo systemctl status -l "$@"
}
function st () {
	echo "Getting status for systemd service $@."
	sudo systemctl status -l "$@"
}
function dr () {
	echo "Executing systemd daemon-reload."
	sudo systemctl daemon-reload
}
EOL



# Replace bashrc
if [[ "$(id -u)" == "0" && -f "/etc/skel/.bashrc" ]]; then
	cp /etc/skel/.bashrc "/root/.bashrc"
	chown 0:0 "/root/.bashrc"
fi

if [ "$(id -u)" == "0" ]; then

	grepadd "CUSTOMSCRIPTPATH=\"$SCRIPTDIR\"" "/root/.bashrc"

	multilineadd "/root/.bashrc" "function stop" <<'EOL'
export EDITOR=nano
export XZ_OPT="-9T0"
alias la='ls -lah --color=auto'
if timeout 3 test -d "$CUSTOMSCRIPTPATH" && ! echo $PATH | grep -iq "$CUSTOMSCRIPTPATH"; then
	export PATH=$PATH:$CUSTOMSCRIPTPATH
fi
function start () {
	echo "Starting systemd service $@."
	systemctl start "$@"
	systemctl status -l "$@"
}
function stop () {
	echo "Stopping systemd service $@."
	systemctl stop "$@"
	systemctl status -l "$@"
}
function en () {
	echo "Enabling systemd service $@."
	systemctl enable "$@"
	systemctl status -l "$@"
}
function dis () {
	echo "Disabling systemd service $@."
	systemctl disable "$@"
	systemctl status -l "$@"
}
function res () {
	echo "Restarting systemd service $@."
	systemctl restart "$@"
	systemctl status -l "$@"
}
function st () {
	echo "Getting status for systemd service $@."
	systemctl status -l "$@"
}
function dr () {
	echo "Executing systemd daemon-reload."
	systemctl daemon-reload
}
EOL
fi

if [[ $(type -P pacman) ]]; then

	multilineadd "$USERHOME/.bashrc" "function pmi" <<'EOL'
function sl () {
	sudo bash
}
function pmi () {
	echo "Installing $@ or updating using pacman."
	sudo pacman -Syu --needed "$@"
}
function ami () {
	echo "Installing $@ using apacman."
	sudo apacman -S --needed --ignorearch "$@"
}
function amin () {
	echo "Installing $@ using apacman."
	sudo apacman -S --needed --noconfirm --ignorearch "$@"
}
function up () {
	echo "Starting full system update using apacman."
	sudo apacman -Syu --noconfirm --ignorearch
}
function rmd () {
	echo "Removing /var/lib/pacman/db.lck."
	sudo rm /var/lib/pacman/db.lck
}
function cln () {
	echo "Removing (supposedly) uneeded packages."
	pacman -Qdtq | sudo pacman -Rs -
}
function rmv () {
	echo "Removing $@ and dependancies using pacman."
	sudo pacman -Rsn "$@"
}
function psc () {
	echo "Searching for $@ using apacman."
	apacman -Ss "$@"
}
function gitup () {
	echo "Upgrading git packages from AUR."
	sudo apacman -S --skipcache --noconfirm --ignorearch $(pacman -Qq | grep -i "\-git")
}
EOL

	if [ "$(id -u)" == "0" ]; then
		multilineadd "/root/.bashrc" "function pmi" <<'EOL'
function pmi () {
	echo "Installing $@ or updating using pacman."
	pacman -Syu --needed "$@"
}
function ami () {
	echo "Installing $@ using apacman."
	apacman -S --needed --ignorearch "$@"
}
function amin () {
	echo "Installing $@ using apacman."
	apacman -S --needed --noconfirm --ignorearch "$@"
}
function up () {
	echo "Starting full system update using apacman."
	apacman -Syu --noconfirm --ignorearch
}
function rmd () {
	echo "Removing /var/lib/pacman/db.lck."
	rm /var/lib/pacman/db.lck
}
function cln () {
	echo "Removing (supposedly) uneeded packages."
	pacman -Qdtq | pacman -Rs -
}
function rmv () {
	echo "Removing $@ and dependancies using pacman."
	pacman -Rsn "$@"
}
function psc () {
	echo "Searching for $@ using apacman."
	apacman -Ss "$@"
}
function gitup () {
	echo "Upgrading git packages from AUR."
	apacman -S --skipcache --noconfirm --ignorearch $(pacman -Qq | grep -i "\-git")
}
EOL
	fi

elif [[ $(type -P apt-get) ]]; then
	
	multilineadd "$USERHOME/.bashrc" "function afix" <<'EOL'
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin
function agi () {
	echo "Installing $@."
	sudo apt-get install "$@"
}
function agiy () {
	echo "Installing $@."
	sudo apt-get install -y "$@"
}
function afix () {
	echo "Running apt-get -f install."
	sudo apt-get -f install
}
function agr () {
	echo "Removing $@."
	sudo apt-get --purge remove "$@"
}
function agu () {
	echo "Updating Repos."
	sudo apt-get update
}
function acs () {
	echo "Searching for $@."
	apt-cache search "$@"
}
function acp () {
	echo "Policy for $@."
	apt-cache policy "$@"
}
function agup () {
	echo "Upgrading system."
	sudo apt-get upgrade
}
function agdup () {
	echo "Dist-upgrading system."
	sudo apt-get dist-upgrade
}
function aar () {
	echo "Auto-removing packages."
	sudo apt-get autoremove --purge
}
function up () {
	echo "Updating and Dist-upgrading system."
	sudo apt-get update
	sudo apt-get dist-upgrade
}
function ark () {
	echo "Removing old kernels."
	sudo apt-get purge $(ls -tr /boot/vmlinuz-* | head -n -2 | grep -v $(uname -r) | cut -d- -f2- | awk '{print "linux-image-" $0 "\nlinux-headers-" $0}')
}
EOL

	if [ "$(id -u)" == "0" ]; then
		multilineadd "/root/.bashrc" "function afix" <<'EOL'
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin
function agi () {
	echo "Installing $@."
	apt-get install "$@"
}
function agiy () {
	echo "Installing $@."
	apt-get install -y "$@"
}
function afix () {
	echo "Running apt-get -f install."
	apt-get -f install
}
function agr () {
	echo "Removing $@."
	apt-get --purge remove "$@"
}
function agu () {
	echo "Updating Repos."
	apt-get update
}
function acs () {
	echo "Searching for $@."
	apt-cache search "$@"
}
function acp () {
	echo "Policy for $@."
	apt-cache policy "$@"
}
function agup () {
	echo "Upgrading system."
	apt-get upgrade
}
function agdup () {
	echo "Dist-upgrading system."
	apt-get dist-upgrade
}
function aar () {
	echo "Auto-removing packages."
	apt-get autoremove --purge
}
function up () {
	echo "Updating and Dist-upgrading system."
	apt-get update
	apt-get dist-upgrade
}
function ark () {
	echo "Removing old kernels."
	apt-get purge $(ls -tr /boot/vmlinuz-* | head -n -2 | grep -v $(uname -r) | cut -d- -f2- | awk '{print "linux-image-" $0 "\nlinux-headers-" $0}')
}
EOL
	fi
	
elif [[ $(type -P dnf) ]]; then
	
	multilineadd "$USERHOME/.bashrc" "function diy" <<'EOL'
function di () {
	echo "Installing $@."
	sudo dnf install "$@"
}
function diy () {
	echo "Installing $@."
	sudo dnf install -y "$@"
}
function dr () {
	echo "Removing $@."
	sudo dnf remove $@
}
function ds () {
	echo "Searching for $@."
	sudo dnf search "$@"
}
function dar () {
	echo "Auto-removing packages."
	sudo dnf autoremove
}
function up () {
	echo "Updating system."
	sudo dnf update -y
}
EOL

	if [ "$(id -u)" == "0" ]; then
		multilineadd "/root/.bashrc" "function diy" <<'EOL'
function di () {
	echo "Installing $@."
	dnf install "$@"
}
function diy () {
	echo "Installing $@."
	dnf install -y "$@"
}
function dr () {
	echo "Removing $@."
	dnf remove "$@"
}
function ds () {
	echo "Searching for $@."
	dnf search "$@"
}
function dar () {
	echo "Auto-removing packages."
	dnf autoremove
}
function up () {
	echo "Updating system."
	dnf update -y
}
EOL
	fi


fi
