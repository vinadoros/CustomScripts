#!/bin/bash

set +eu

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

# Install apache
dist_install apache openssl

# Install php
dist_install php php-apache php-apcu php-intl php-mcrypt php-fpm php-gd xdebug

# Install mysql/mariadb
dist_install mariadb

# Reload systemd services before running mysql commands.
systemctl daemon-reload

set -eu

# Php changes

# Uncomment lines in php.ini
sed -i '/^;.*=opcache.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=gd.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=iconv.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=xmlrpc.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=zip.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=bz2.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=curl.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=intl.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=mcrypt.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=openssl.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=pdo_mysql.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=mysqli.so/s/^;//' /etc/php/php.ini
sed -i '/^;.*=apcu.so/s/^;//' /etc/php/conf.d/apcu.ini
grepadd "apc.enable_cli=1" /etc/php/conf.d/apcu.ini

# Add date.timezone
sed -i '/^;date.timezone =.*/s/^;//' /etc/php/php.ini
sed -i 's@^date.timezone =.*@date.timezone = "America/New_York"@' /etc/php/php.ini

# Apache/httpd.conf changes
sed -i '/^#LoadModule rewrite_module modules\/mod_rewrite.so/s/^#//g' /etc/httpd/conf/httpd.conf
# Include php7 in apache
if ! grep -q "^Include conf/extra/php7_module.conf" "/etc/httpd/conf/httpd.conf"; then
	echo "Include conf/extra/php7_module.conf" >> /etc/httpd/conf/httpd.conf
fi
if grep -q "^LoadModule mpm_event_module modules/mod_mpm_event.so" /etc/httpd/conf/httpd.conf; then
	sed -i '/^LoadModule mpm_event_module modules\/mod_mpm_event.so/s/^/#/g' /etc/httpd/conf/httpd.conf
	sed -i '/^#LoadModule mpm_prefork_module modules\/mod_mpm_prefork.so/s/^#//g' /etc/httpd/conf/httpd.conf
fi
if grep -q "^LoadModule dav_module modules/mod_dav.so" /etc/httpd/conf/httpd.conf; then
	sed -i '/^LoadModule dav_module modules\/mod_dav.so/s/^/#/g' /etc/httpd/conf/httpd.conf
fi
if grep -q "^LoadModule dav_fs_module modules/mod_dav_fs.so" /etc/httpd/conf/httpd.conf; then
	sed -i '/^LoadModule dav_fs_module modules\/mod_dav_fs.so/s/^/#/g' /etc/httpd/conf/httpd.conf
fi
if ! grep -q "^LoadModule php7_module modules/libphp7.so" /etc/httpd/conf/httpd.conf; then
	sed -i "/LoadModule dir_module modules\/mod_dir.so/aLoadModule php7_module modules\/libphp7.so" /etc/httpd/conf/httpd.conf
fi

#sed -i "s/^Listen .*/Listen 0.0.0.0:80/" /etc/httpd/conf/httpd.conf

# Setup mariadb.
set +eu
if [ ! -f /var/lib/mysql/mysql-bin.000001 ]; then
	systemctl stop mysqld
	mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
	systemctl restart mysqld
	mysql_secure_installation
fi
set -eu

systemctl enable mysqld
systemctl restart mysqld
systemctl enable httpd
systemctl restart httpd


echo "Script finished successfully."
