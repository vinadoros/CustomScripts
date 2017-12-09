#!/usr/bin/env bash

# Setup koel
# https://koel.phanan.net/docs
if [ ! -d /var/www/koel ]; then
  git clone https://github.com/phanan/koel.git /var/www/koel
  REPOEMPTY=1
else
  REPOEMPTY=0
fi
cd /var/www/koel
# Setup env file
if [ ! -f .env ]; then
  cp .env.example .env
  # Prepare database
  mysql -h db -u root -p$DBPASSWD -e "CREATE DATABASE IF NOT EXISTS koel;"
  DBEMPTY=1
else
  DBEMPTY=0
fi
sed -i "s/^ADMIN_EMAIL=.*/ADMIN_EMAIL=$ADMINUSER/g" .env
sed -i 's/^ADMIN_NAME=.*/ADMIN_NAME=admin/g' .env
sed -i "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$ADMINPASS/g" .env
sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/g' .env
sed -i 's/^DB_HOST=.*/DB_HOST=db/g' .env
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=koel/g' .env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=root/g" .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DBPASSWD/g" .env
if [ $REPOEMPTY = 1 ]; then
  # Install composer packages
  composer install
fi

# Ensure everything is up to date
composer update
php artisan koel:init
if [ $REPOEMPTY = 0 ]; then
  php artisan koel:sync
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
