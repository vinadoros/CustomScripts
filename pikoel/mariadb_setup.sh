#!/usr/bin/env bash

if [ ! -f /var/lib/mysql/ibdata1 ]; then
  # Create mysql tables
  mysql_install_db
  # Load mysql in safe mode
  mysqld_safe &
  # Wait for the daemon to appear.
  sleep 3
  # Set the root password
  mysqladmin -u root password $DBPASSWD
  # Hopefully end mysqld.
  killall mysqld_safe mysqld
  # Wait until mysqld is gone
  sleep 3
else
  echo "mariadb files exist."
fi

# Start mariadb
/etc/init.d/mysql restart
