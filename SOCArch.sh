#!/bin/bash

set -e

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Add general functions if they don't exist.
type -t grepadd &> /dev/null || source "$SCRIPTDIR/Comp-GeneralFunctions.sh"

if [ "$(id -u)" != "0" ]; then
	echo "Not running with root. Please run the script with su privledges."
	exit 1;
fi

echo "Installing LAMP stack."
source "$SCRIPTDIR/Slamp.sh"

OCDATAPATH=""

dist_install owncloud ffmpeg openssl

if [ -d /usr/share/webapps/owncloud ]; then
	OCLOCATION="/usr/share/webapps/owncloud"
elif [ -d /var/www/owncloud ]; then
	OCLOCATION="/var/www/owncloud"
else
	echo "Owncloud folder not detected. Exiting."
	exit 1;
fi
OCLOCALCONFIG="/etc/webapps/owncloud/config/config.php"

OCDEFAULTDATADIRECTORY="/usr/share/webapps/owncloud/data"
read -p "Input a OC data location (Default is $OCDEFAULTDATADIRECTORY): " OCDATADIRECTORY
OCDATADIRECTORY=$(readlink -f "${OCDATADIRECTORY%/}")
if [[ -z "$OCDATADIRECTORY" ]]; then
	echo "No input found. Defaulting to $OCDEFAULTDATADIRECTORY."
	OCDATADIRECTORY="$OCDEFAULTDATADIRECTORY"
elif [ -d "$OCDATADIRECTORY" ]; then
	echo "Setting OC data folder to ${OCDATADIRECTORY}"
else
	echo "Invalid setting. Exiting."
	exit 1;
fi

HTTPSPORT=64030
read -p "Input a HTTPS port (Default is $HTTPSPORT): " NEWHTTPSPORT
NEWHTTPSPORT=${NEWHTTPSPORT//[^0-9_]/}
if [[ -z "$NEWHTTPSPORT" ]]; then
	echo "No input found. Defaulting to $HTTPSPORT."
else
	echo "Setting HTTPS port to $NEWHTTPSPORT"
	HTTPSPORT=$NEWHTTPSPORT
fi

read -p "Press any key to continue."
echo ""

set -u

if [ -d "$OCDATADIRECTORY" ]; then
	touch "${OCDATADIRECTORY}/.ocdata"
	chown http:http -R "$OCDATADIRECTORY"
	chown http:http "$OCDATADIRECTORY/../"
	chmod 755 "$OCDATADIRECTORY"
fi

chown -R http:http "${OCLOCATION}"

if [ ! -f /etc/httpd/conf/extra/owncloud.conf ]; then
	cp /etc/webapps/owncloud/apache.example.conf /etc/httpd/conf/extra/owncloud.conf
fi

# httpd.conf changes
sed -i '/^#LoadModule ssl_module modules\/mod_ssl.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/^#LoadModule socache_shmcb_module modules\/mod_socache_shmcb.so/s/^#//g' /etc/httpd/conf/httpd.conf
sed -i '/^#Include conf\/extra\/httpd-ssl.conf/s/^#//g' /etc/httpd/conf/httpd.conf

if ! grep -q "^Include conf/extra/owncloud.conf" "/etc/httpd/conf/httpd.conf"; then
	echo "Include conf/extra/owncloud.conf" >> /etc/httpd/conf/httpd.conf
fi

# Listen on port 80 only with localhost.
sed -i "s/^Listen .*/Listen 127.0.0.1:80/" /etc/httpd/conf/httpd.conf

#Https changes
sed -i "s/^Listen .*/Listen "$HTTPSPORT" https/" /etc/httpd/conf/extra/httpd-ssl.conf
sed -i "s@^DocumentRoot .*@DocumentRoot \"${OCLOCATION}\"@" /etc/httpd/conf/extra/httpd-ssl.conf
sed -i "s/^<VirtualHost _default_:.*>/<VirtualHost _default_:${HTTPSPORT}>/" /etc/httpd/conf/extra/httpd-ssl.conf

#chown -R http:http /usr/share/webapps/owncloud/

if [ ! -f /etc/httpd/conf/server.crt ]; then
	echo "Generating openssh keys."
	openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out /etc/httpd/conf/server.key
	chmod 600 /etc/httpd/conf/server.key
	openssl req -new -key /etc/httpd/conf/server.key -out /etc/httpd/conf/server.csr -subj '/C=US/ST=SomeState/CN=Test'
	openssl x509 -req -days 3652 -in /etc/httpd/conf/server.csr -signkey /etc/httpd/conf/server.key -out /etc/httpd/conf/server.crt
fi

systemctl enable mysqld
systemctl restart mysqld
systemctl enable httpd
systemctl restart httpd

sleep 1

if [ ! -f "$OCLOCALCONFIG" ] || ! grep -q "'datadirectory'" "$OCLOCALCONFIG"; then
	set +e
	xdg-open http://127.0.0.1/
	set -e
fi

sleep 3

if [ -f "$OCLOCALCONFIG" ] && ! grep -q "memcache.local" "$OCLOCALCONFIG"; then
	sed -i "/'installed'/a\ \ \'memcache\.local\' => \'\\\OC\\\Memcache\\\APCu\'," "$OCLOCALCONFIG"
fi

if [ -f "$OCLOCALCONFIG" ] && ! $(grep "'datadirectory'" "$OCLOCALCONFIG" | grep -q "$OCDATADIRECTORY" "$OCLOCALCONFIG"); then
	echo "Changing OC data folder to ${OCDATADIRECTORY} in $OCLOCALCONFIG."
	sed -i "s@\('datadirectory' => '\)\(.*\)\(',\)@\1${OCDATADIRECTORY}\3@" "$OCLOCALCONFIG"
fi

if ! $(grep "php_admin_value" /etc/httpd/conf/extra/owncloud.conf | grep -q "$OCDATADIRECTORY" /etc/httpd/conf/extra/owncloud.conf); then
	echo "Changing OC data folder in /etc/httpd/conf/extra/owncloud.conf."
	sed -i "s@\(php_admin_value\ open_basedir.*/etc/webapps/owncloud\)\(.*\"\)@\1:$OCDATADIRECTORY\"@" /etc/httpd/conf/extra/owncloud.conf
fi

systemctl restart httpd

echo "Script finished successfully."
