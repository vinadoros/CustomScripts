#!/usr/bin/env bash
set -ex

if [ ! -f /var/lib/mysql/ibdata1 ]; then
  mysql_install_db
else
  echo "mysql db exists."
fi
