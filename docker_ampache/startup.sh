#!/bin/bash

# Setup ampache
if [ ! -d /var/www/ampache ]; then
  git clone https://github.com/ampache/ampache /var/www/ampache
  cd /var/www/ampache
  composer install
  composer update
fi
cd /var/www
chmod a+rw -R /var/www/ampache

# Setup ampache.config
if [ ! -f /var/www/ampache/config/ampache.cfg.php ]; then
  # Check for template file
  if [ -f /var/www/ampache/config/ampache.cfg.php.dist ]; then
    cp -a /var/www/ampache/config/ampache.cfg.php.dist /var/www/ampache/config/ampache.cfg.php
  fi
  # Modify template variables
  sed -i '/^;http_port.*/s/^;//g' /var/www/ampache/config/ampache.cfg.php
  sed -i "s/^http_port.*/http_port = $PROXY_PORT/g" /var/www/ampache/config/ampache.cfg.php
  sed -i '/^;web_path.*/s/^;//g' /var/www/ampache/config/ampache.cfg.php
  sed -i 's@^web_path.*@web_path = "/ampache"@g' /var/www/ampache/config/ampache.cfg.php
  sed -i 's@^database_hostname =.*@database_hostname = db@g' /var/www/ampache/config/ampache.cfg.php
  sed -i 's@^database_username =.*@database_username = root@g' /var/www/ampache/config/ampache.cfg.php
  sed -i "s@^database_password =.*@database_password = $MYSQL_ROOT_PASSWORD@g" /var/www/ampache/config/ampache.cfg.php
  SECRETKEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
  sed -i "s@^secret_key =.*@secret_key = \"$SECRETKEY\"@g" /var/www/ampache/config/ampache.cfg.php
  mysql -h db -u root -p$MYSQL_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS ampache;"
  mysql -h db -u root -p$MYSQL_ROOT_PASSWORD ampache < /var/www/ampache/sql/ampache.sql
fi

# Setup htaccess files
[ ! -f /var/www/ampache/rest/.htaccess ] && cp -a /var/www/ampache/rest/.htaccess.dist /var/www/ampache/rest/.htaccess
[ ! -f /var/www/ampache/channel/.htaccess ] && cp -a /var/www/ampache/channel/.htaccess.dist /var/www/ampache/channel/.htaccess
[ ! -f /var/www/ampache/play/.htaccess ] && cp -a /var/www/ampache/play/.htaccess.dist /var/www/ampache/play/.htaccess
# Set webpath to /ampache in htaccess
sed -i 's@ /@ /ampache/@g' /var/www/ampache/rest/.htaccess /var/www/ampache/channel/.htaccess /var/www/ampache/play/.htaccess

# Run apache
apache2ctl -D FOREGROUND
