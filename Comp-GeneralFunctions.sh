#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

grepadd () {
		if [ -z "$1" ]; then
			echo "No parameter passed."
			return 1;
		else
			FINDSTRING="$1"
		fi

		if [ -z "$2" ]; then
			echo "No parameter passed."
			return 1;
		else
			FINDINFILE="$2"
		fi

		if ! grep -iq "${FINDSTRING}" "${FINDINFILE}"; then
			echo "Adding $FINDSTRING to $FINDINFILE"
			echo "${FINDSTRING}" >> "${FINDINFILE}"
		fi
}

grepcheckadd () {
		if [ -z "$1" ]; then
			echo "No parameter passed."
			return 1;
		else
			INSERTSTRING="$1"
		fi

		if [ -z "$2" ]; then
			echo "No parameter passed."
			return 1;
		else
			SEARCHSTRING="$2"
		fi

		if [ -z "$3" ]; then
			echo "No parameter passed."
			return 1;
		else
			FINDINFILE="$3"
		fi

		if ! grep -iq "${SEARCHSTRING}" "${FINDINFILE}"; then
			echo "Adding $INSERTSTRING to $FINDINFILE"
			echo -e "${INSERTSTRING}" >> "${FINDINFILE}"
		fi
}

multilinereplace () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		SAVETOFILE="$(readlink -f $1)"
	fi

	MULTILINE="$(cat /dev/stdin)"
	if [ -d "$(dirname $SAVETOFILE)" ]; then
		echo "Creating $SAVETOFILE."
		echo "$MULTILINE" > "$SAVETOFILE"
		chmod a+rwx "$SAVETOFILE"
	else
		echo "Not creating $SAVETOFILE. Base folder $(dirname $SAVETOFILE) does not exist."
	fi
}

multilineadd () {
	if [ -z "$1" ]; then
		echo "No parameter passed."
		return 1;
	else
		SAVETOFILE="$1"
	fi

	MULTILINE="$(cat /dev/stdin)"
	if [ -z "$MULTILINE" ]; then
		echo "No text found."
		return 1;
	fi

	if [ -z "$2" ]; then
		echo "Adding text block to $SAVETOFILE"
		echo "${MULTILINE}" >> "${SAVETOFILE}"
	else
		TESTSTRING="$2"
		if ! grep -iq "${TESTSTRING}" "${SAVETOFILE}"; then
			echo "Adding text block to $SAVETOFILE"
			echo "${MULTILINE}" >> "${SAVETOFILE}"
		fi
	fi

}

nscriptadd () {
	if [ -z "$1" ]; then
		echo "No source file passed."
		return 1;
	else
		SOURCEFILE="$1"
	fi

	if [ -z "$2" ]; then
		echo "No destination file passed."
		return 1;
	else
		DESTFILE="$2"
	fi

	echo "Adding $SOURCEFILE."

	echo "echo \"Executing $SOURCEFILE.\"" >> "${DESTFILE}"
	cat "$SOURCEFILE" >> "${DESTFILE}"

	sed -i '/# Get folder of this script/d' "${DESTFILE}"
	sed -i '/SCRIPTSOURCE="${BASH_SOURCE\[0\]}"/d' "${DESTFILE}"
	sed -i '/FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"/d' "${DESTFILE}"
	sed -i '/SCRIPTDIR="$(dirname "$FLWSOURCE")"/d' "${DESTFILE}"
	sed -i '/SCRNAME="$(basename $SCRIPTSOURCE)"/d' "${DESTFILE}"
	sed -i '/echo "Executing ${SCRNAME}."/d' "${DESTFILE}"

}

# Install pkg commands for distributions.
dist_install () {
	INSTALLPKGS="$@"
	[ "$(id -u)" != "0" ] && SUDOCMD="sudo" || SUDOCMD=""

	if type -p apacman &> /dev/null; then
		echo "Installing $INSTALLPKGS using AUR helper."
		$SUDOCMD apacman -S --needed --noconfirm --ignorearch $INSTALLPKGS
	elif type -p pacman &> /dev/null; then
		echo "Installing $INSTALLPKGS using pacman."
		$SUDOCMD pacman -Syu --needed --noconfirm $INSTALLPKGS
	elif type -p apt-get &> /dev/null; then
		echo "Installing $INSTALLPKGS using apt-get."
		$SUDOCMD apt-get install -y $INSTALLPKGS
	elif type -p dnf &> /dev/null; then
		echo "Installing $INSTALLPKGS using dnf."
		$SUDOCMD dnf install -y $INSTALLPKGS
	fi

}

# Stock install pkg commands that will always work.
dist_install_bare () {
	INSTALLPKGS="$@"
	[ "$(id -u)" != "0" ] && SUDOCMD="sudo" || SUDOCMD=""

	if type -p pacman &> /dev/null; then
		echo "Installing $INSTALLPKGS using pacman."
		$SUDOCMD pacman -S --noconfirm $INSTALLPKGS
	elif type -p apt-get &> /dev/null; then
		echo "Installing $INSTALLPKGS using apt-get."
		$SUDOCMD apt-get install -y $INSTALLPKGS
	elif type -p dnf &> /dev/null; then
		echo "Installing $INSTALLPKGS using dnf."
		$SUDOCMD dnf install -y $INSTALLPKGS
	fi

}

# Remove pkg with dependancies.
dist_remove_deps () {
	REMOVEPKGS="$@"
	[ "$(id -u)" != "0" ] && SUDOCMD="sudo" || SUDOCMD=""

	for pkg in $REMOVEPKGS; do
		if type -p pacman &> /dev/null && pacman -Qq | grep -iq "^$pkg$"; then
			echo "Removing $pkg using pacman."
			$SUDOCMD pacman -Rsn --noconfirm "$pkg"
		elif type -p apt-get &> /dev/null && dpkg-query -W -f='${Package}' "$pkg" &> /dev/null; then
			echo "Removing $pkg using apt-get."
			$SUDOCMD apt-get --purge remove -y "$pkg"
		elif type -p dnf &> /dev/null && dnf list installed | grep -i "$pkg"; then
			echo "Removing $pkg using dnf."
			$SUDOCMD dnf remove -y "$pkg"
		fi
	done

}

# Force remove pkg.
dist_remove_force () {
	REMOVEPKGS="$@"
	[ "$(id -u)" != "0" ] && SUDOCMD="sudo" || SUDOCMD=""

	for pkg in $REMOVEPKGS; do
		if type -p pacman &> /dev/null && pacman -Qq | grep -iq "^$pkg$"; then
			echo "Removing $pkg using pacman."
			$SUDOCMD pacman -Rdd --noconfirm "$pkg"
		elif type -p apt-get &> /dev/null && dpkg-query -W -f='${Package}' "$pkg" &> /dev/null; then
			echo "Removing $pkg using apt-get."
			$SUDOCMD apt-get --purge remove -y "$pkg"
		elif type -p dnf &> /dev/null && dnf list installed | grep -i "$pkg"; then
			echo "Removing $pkg using dnf."
			$SUDOCMD dnf remove -y "$pkg"
		fi
	done

}

# Commands to upgrade all packages in distro.
dist_update () {
	[ "$(id -u)" != "0" ] && SUDOCMD="sudo" || SUDOCMD=""

	if type -p apacman &> /dev/null; then
		echo "Updating system using apacman."
		$SUDOCMD apacman -Syu --noconfirm --ignorearch
	elif type -p pacman &> /dev/null; then
		echo "Updating system using pacman."
		$SUDOCMD pacman -Syu --noconfirm
	elif type -p apt-get &> /dev/null; then
		echo "Updating system using apt-get."
		$SUDOCMD apt-get update
		$SUDOCMD apt-get upgrade -y
		$SUDOCMD apt-get dist-upgrade -y
	elif type -p dnf &> /dev/null; then
		echo "Updating system using dnf."
		$SUDOCMD dnf update -y
	fi

}

# Command to update grub configuration in distributions.
grub_update () {
	[ "$(id -u)" != "0" ] && SUDOCMD="sudo" || SUDOCMD=""

	if type -P update-grub &> /dev/null; then
		echo "Updating grub config using update-grub."
		$SUDOCMD update-grub
	elif [[ -f /boot/grub2/grub.cfg ]]; then
		echo "Updating grub config using mkconfig grub2."
		$SUDOCMD grub2-mkconfig -o /boot/grub2/grub.cfg
	elif [[ -d /boot/grub/ ]]; then
		echo "Updating grub config using mkconfig grub."
		$SUDOCMD grub-mkconfig -o /boot/grub/grub.cfg
	fi

}
