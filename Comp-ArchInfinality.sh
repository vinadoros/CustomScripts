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

if [ -z $MACHINEARCH ]; then
	MACHINEARCH=$(uname -m)
fi

# Enable error halting.
set -eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

###############################################################################
########################        Infinality Fonts      #########################
###############################################################################
# https://bbs.archlinux.org/viewtopic.php?id=162098&p=1

# Disable the error exiting (it interferes with the script's ability to insert lines in the pacman.conf).
set +e
if ! grep -Fq "infinality-bundle" /etc/pacman.conf; then

	if [ "${MACHINEARCH}" = "x86_64" ]; then

		while read line
		do
		echo $line | grep -q "#\[testing\]"
		[ $? -eq 0 ] && cat <<"EOL"
[infinality-bundle]
Server = http://bohoomil.com/repo/$arch

[infinality-bundle-multilib]
Server = http://bohoomil.com/repo/multilib/$arch

[infinality-bundle-fonts]
Server = http://bohoomil.com/repo/fonts

EOL

		echo $line
		done < /etc/pacman.conf | cat > ~/pacman.conf.new

	else

		while read line
		do
		echo $line | grep -q "#\[testing\]"
		[ $? -eq 0 ] && cat <<"EOL"
[infinality-bundle]
Server = http://bohoomil.com/repo/$arch

[infinality-bundle-fonts]
Server = http://bohoomil.com/repo/fonts

EOL

		echo $line
		done < /etc/pacman.conf | cat > ~/pacman.conf.new

	fi

	if grep -Fq "[infinality-bundle]" ~/pacman.conf.new; then
		echo "Replacing pacman.conf"
		rm /etc/pacman.conf
		mv ~/pacman.conf.new /etc/pacman.conf
	else
		echo "Infinality repo not found in pacman.conf.new. Exiting."
		exit 1;
	fi

	until pacman-key -r 962DDE58
		do echo "Trying again in 1 seconds."
		sleep 1
	done
	until pacman-key --lsign-key 962DDE58
		do echo "Trying again in 1 seconds."
		sleep 1
	done

fi

if ! grep -Fq "infinality-bundle" /etc/pacman.conf; then
	echo "Infinality repo not found in pacman.conf. Exiting."
	exit 1;
fi

pacman -Syy

# First remove all packages that are incompatible with infinality-fonts.
if ! pacman -Q | grep -i "freetype2-infinality"; then
	echo "Removing existing font packages."
	pacman -Rdd --noconfirm ttf-dejavu
	pacman -Rdd --noconfirm ttf-liberation
	pacman -Rdd --noconfirm ttf-google-fonts
	pacman -Rdd --noconfirm cantarell-fonts
	pacman -Rdd --noconfirm gsfonts
	pacman -Rdd --noconfirm cairo
	pacman -Rdd --noconfirm fontconfig
	pacman -Rdd --noconfirm freetype2
	pacman -Rdd --noconfirm noto-fonts
fi

if [ ${MACHINEARCH} == "x86_64" ] && ! pacman -Q | grep -i "lib32-freetype2-infinality"; then
	echo "Removing 32-bit font packages."
	pacman -Rdd --noconfirm lib32-freetype2
	pacman -Rdd --noconfirm lib32-fontconfig
fi

# Re-enable the error-detection
set -e

# Now install infinality-fonts.
if [ "${MACHINEARCH}" == "x86_64" ]; then
	until pacman -S --needed --noconfirm infinality-bundle infinality-bundle-multilib ibfonts-meta-base ibfonts-meta-extended
		do echo "Trying again in 2 seconds."
		sleep 2
	done
else
	until pacman -S --needed --noconfirm infinality-bundle ibfonts-meta-base ibfonts-meta-extended
		do echo "Trying again in 2 seconds."
		sleep 2
	done
fi
