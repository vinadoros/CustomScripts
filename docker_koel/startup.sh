#!/usr/bin/env bash

# Setup koel
# https://koel.phanan.net/docs
if [ ! -d /var/www/koel ]; then
  git clone https://github.com/phanan/koel.git /var/www/koel
fi
cd /var/www/koel
# Setup env file
if [ ! -f .env ]; then
  cp .env.example .env
  # Prepare database
  mysql -h db -u root -p$DBPASSWD -e "CREATE DATABASE IF NOT EXISTS ampache;"
  DBEMPTY=1
else
  DBEMPTY=0
fi
chown www-data:www-data /var/www/db.sqlite
chmod a+rw /var/www/db.sqlite
sed -i 's/^ADMIN_EMAIL=.*/ADMIN_EMAIL=a@l.c/g' .env
sed -i 's/^ADMIN_NAME=.*/ADMIN_NAME=admin/g' .env
sed -i "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$ADMINPASS/g" .env
sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/g' .env
sed -i 's/^DB_HOST=.*/DB_HOST=db/g' .env
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=koel/g' .env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=root/g" .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DBPASSWD/g" .env
if [ $DBEMPTY = 1 ]; then
  # Update composer packages
  composer install
  composer update
  # Build node-sass (which doesn't have an arm package)
  npm rebuild node-sass
  # Init database
  php artisan koel:init
fi

# Start php-fpm
/etc/init.d/php7.0-fpm start
# Set permissions on folder and start nginx
chown www-data:www-data -R /var/www/
/etc/init.d/nginx start
# To run nginx in foreground as root
# nginx -g 'daemon off;'

# Loop forever once nginx starts
while true; do
  sleep 10
done
