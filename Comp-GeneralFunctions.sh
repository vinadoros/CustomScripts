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
		SAVETOFILE="$1"
	fi
	
	MULTILINE="$(cat /dev/stdin)"
	echo "Creating $SAVETOFILE."
	echo "$MULTILINE" > "$SAVETOFILE"
	chmod a+rwx "$SAVETOFILE"
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
	
	if [ $(type -p pacman &> /dev/null) ]; then
		echo "Installing $INSTALLPKGS using pacman."
		pacman -Syu --needed --noconfirm "$INSTALLPKGS"
	elif [ $(type -p apt-get &> /dev/null) ]; then
		echo "Installing $INSTALLPKGS using apt-get."
		apt-get update
		apt-get install -y "$INSTALLPKGS"
	elif [ $(type -p dnf &> /dev/null) ]; then
		echo "Installing $INSTALLPKGS using dnf."
		dnf install -y "$INSTALLPKGS"
	fi
	
}

# Stock install pkg commands that will always work.
dist_install_bare () {
	INSTALLPKGS="$@"
	
	if [ $(type -p pacman &> /dev/null) ]; then
		echo "Installing $INSTALLPKGS using pacman."
		pacman -S --noconfirm "$INSTALLPKGS"
	elif [ $(type -p apt-get &> /dev/null) ]; then
		echo "Installing $INSTALLPKGS using apt-get."
		apt-get install -y "$INSTALLPKGS"
	elif [ $(type -p dnf &> /dev/null) ]; then
		echo "Installing $INSTALLPKGS using dnf."
		dnf install -y "$INSTALLPKGS"
	fi
	
}

# Commands to upgrade all packages in distro.
dist_update () {
	
	if [ $(type -p pacman &> /dev/null) ]; then
		echo "Updating system using pacman."
		pacman -Syu --noconfirm
	elif [ $(type -p apt-get &> /dev/null) ]; then
		echo "Updating system using apt-get."
		apt-get update
		apt-get upgrade -y
		apt-get dist-upgrade -y
	elif [ $(type -p dnf &> /dev/null) ]; then
		echo "Updating system using dnf."
		dnf update -y
	fi
	
}

