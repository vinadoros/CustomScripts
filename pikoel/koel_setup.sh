#!/usr/bin/env bash
set -ex

cd /var/www/koel
if [ ! -f ./updated ]; then
  # Setup mariadb database.
  if [ ! -z $DBPASSWD ]; then
    mysql -u root -p$DBPASSWD -e "CREATE DATABASE IF NOT EXISTS koel DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
    mysql -u root -p$DBPASSWD -e "CREATE USER IF NOT EXISTS 'koel-user'@'localhost';"
    mysql -u root -p$DBPASSWD -e "SET PASSWORD FOR 'koel-user'@'localhost'= PASSWORD('$DBPASSWD');"
    mysql -u root -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON koel.* TO 'koel-user'@'localhost' WITH GRANT OPTION;"
  fi
  # Setup env file
  if [ ! -f .env ]; then
    cp .env.example .env
  fi
  sed -i 's/^ADMIN_EMAIL=.*/ADMIN_EMAIL=admin@example.com/g' .env
  sed -i 's/^ADMIN_NAME=.*/ADMIN_NAME=admin/g' .env
  sed -i 's/^ADMIN_PASSWORD=.*/ADMIN_PASSWORD=pass/g' .env
  sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/g' .env
  sed -i 's/^DB_HOST=.*/DB_HOST=localhost/g' .env
  sed -i 's/^DB_DATABASE=.*/DB_DATABASE=koel/g' .env
  sed -i 's/^DB_USERNAME=.*/DB_USERNAME=koel-user/g' .env
  sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=$DBPASSWD/g" .env
  # Update composer packages
  composer install
  # Init database
  php artisan koel:init
  # Create file to say repo has been set up.
  touch ./updated
fi
