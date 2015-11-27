#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

# Set user folders if they don't exist.
if [ -z $USERNAMEVAR ]; then
	if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
		export USERNAMEVAR="$SUDO_USER"
	elif [ "$USER" != "root" ]; then
		export USERNAMEVAR="$USER"
	else
		export USERNAMEVAR="$(id 1000 -un)"
	fi
	USERGROUP="$(id 1000 -gn)"
	USERHOME="/home/$USERNAMEVAR"
fi

# Enable error halting.
set -eu

# Set tar file from url here.
FCRONTAR="fcron-3.2.0.src.tar.gz"

# Install dependancies for debian.
[ $(type -p apt-get) ] && apt-get install -y gcc libreadline-dev libpam0g-dev docbook-dsssl

wget ftp://ftp.seul.org/pub/fcron/$FCRONTAR
tar -xzf fcron-*.tar.gz
cd fcron-*
./configure --prefix=/usr --sysconfdir=/etc --with-systemdsystemunitdir=/lib/systemd/system --with-boot-install=no --with-answer-all=no --datarootdir=/usr/share --datadir=/usr/share --with-docdir=/usr/share/doc --localstatedir=/var --with-piddir=/run --with-editor=/bin/nano --without-sendmail
make

# Create fcron user and group.
getent group fcron >/dev/null || groupadd -g 23 fcron
getent passwd fcron >/dev/null || useradd -r -d /var/spool/fcron -u 23 -g 23 fcron

make install

# Cleanup build folder and tar file.
cd ..
rm -rf fcron-*

# Enable cron service.
systemctl enable fcron

# Install usual cron folders.
install -d -m755 "/etc/cron.daily"
install -d -m755 "/etc/cron.hourly"
install -d -m755 "/etc/cron.monthly"
install -d -m755 "/etc/cron.weekly"

# Create systab for anacron/cron support.
bash -c "cat >/var/spool/fcron/systab.orig" <<'EOL'
&bootrun 01 * * * *  /bin/run-parts /etc/cron.hourly
&bootrun 02 00 * * * /bin/run-parts /etc/cron.daily
&bootrun 22 00 * * 0 /bin/run-parts /etc/cron.weekly
&bootrun 42 00 1 * * /bin/run-parts /etc/cron.monthly
EOL
chmod 640 /var/spool/fcron/systab.orig

# Install systab
fcrontab -z -u systab &>/dev/null

echo "Fcron installed successfully."
