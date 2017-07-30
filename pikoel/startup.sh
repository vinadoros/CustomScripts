#!/usr/bin/env bash

# Perform if database folder is empty.
if [ ! -f /var/lib/mysql/ibdata1 ]; then
  # Create mysql tables
  mysql_install_db
  # Load mysql in safe mode
  mysqld_safe &
  # Set the root password
  status=1
  while [ $status != 0 ]; do
    sleep 2
    mysqladmin -u root password $DBPASSWD
    status=$?
  done
  # Hopefully end mysqld.
  killall mysqld_safe mysqld
  # Wait until mysqld is gone
  sleep 3
else
  echo "mariadb files exist."
fi

# Start mariadb
/etc/init.d/mysql restart

# Setup mariadb database.
if [ ! -z $DBPASSWD ]; then
  mysql -u root -p$DBPASSWD -e "CREATE DATABASE IF NOT EXISTS koel DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
  mysql -u root -p$DBPASSWD -e "CREATE USER IF NOT EXISTS 'koel-user'@'localhost';"
  mysql -u root -p$DBPASSWD -e "SET PASSWORD FOR 'koel-user'@'localhost'= PASSWORD('$DBPASSWD');"
  mysql -u root -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON koel.* TO 'koel-user'@'localhost' WITH GRANT OPTION;"
fi

# Setup koel
# https://koel.phanan.net/docs
if [ ! -d /var/www/koel ]; then
  git clone https://github.com/phanan/koel.git /var/www/koel
fi
cd /var/www/koel
# Setup env file
if [ ! -f .env ]; then
  cp .env.example .env
fi
sed -i 's/^ADMIN_EMAIL=.*/ADMIN_EMAIL=a@l.c/g' .env
sed -i 's/^ADMIN_NAME=.*/ADMIN_NAME=admin/g' .env
sed -i "s/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=$ADMINPASS/g" .env
sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/g' .env
sed -i 's/^DB_HOST=.*/DB_HOST=localhost/g' .env
sed -i 's/^DB_DATABASE=.*/DB_DATABASE=koel/g' .env
sed -i 's/^DB_USERNAME=.*/DB_USERNAME=koel-user/g' .env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DBPASSWD/g" .env
if [ ! -f ./updated ]; then
  # Update composer packages
  composer install
  # Build node-sass (which doesn't have an arm package)
  npm rebuild node-sass
  # Init database
  php artisan koel:init
  # Create file to say repo has been set up.
  touch ./updated
fi

# Start php-fpm
/etc/init.d/php7.0-fpm start
# Set permissions on folder and start nginx
chown www-data:www-data -R /var/www/koel
/etc/init.d/nginx start
# To run nginx in foreground as root
# nginx -g 'daemon off;'

# Loop forever once nginx starts
while true; do
  sleep 10
done
