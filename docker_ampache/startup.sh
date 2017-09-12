#!/bin/bash

# Setup ampache
cd /var/www
if [ ! -d /var/www/ampache ]; then
  git clone https://github.com/ampache/ampache /var/www/ampache
fi
chmod a+rw -R /var/www/ampache

# Setup ampache.config
if [ ! -f /var/www/ampache/config/ampache.cfg.php ]; then
  # Check for template file
  if [ -f /var/www/ampache/config/ampache.cfg.php.dist ]; then
    # Modify template variables
    sed -i '/^;http_port.*/s/^;//g' /var/www/ampache/config/ampache.cfg.php.dist
    sed -i "s/^http_port.*/http_port = $PROXY_PORT/g" /var/www/ampache/config/ampache.cfg.php.dist
    sed -i '/^;web_path.*/s/^;//g' /var/www/ampache/config/ampache.cfg.php.dist
    sed -i 's@^web_path.*@web_path = "/ampache"@g' /var/www/ampache/config/ampache.cfg.php.dist
    sed -i 's@^database_name =.*@database_name = db@g' /var/www/ampache/config/ampache.cfg.php.dist
  fi
fi

# Setup htaccess files
[ ! -f /var/www/ampache/rest/.htaccess ] && cp -a /var/www/ampache/rest/.htaccess.dist /var/www/ampache/rest/.htaccess
[ ! -f /var/www/ampache/channel/.htaccess ] && cp -a /var/www/ampache/channel/.htaccess.dist /var/www/ampache/channel/.htaccess
[ ! -f /var/www/ampache/play/.htaccess ] && cp -a /var/www/ampache/play/.htaccess.dist /var/www/ampache/play/.htaccess
# Set webpath to /ampache in htaccess
sed -i 's@ /@ /ampache/@g' /var/www/ampache/rest/.htaccess /var/www/ampache/channel/.htaccess /var/www/ampache/play/.htaccess

# Run apache
apache2ctl -D FOREGROUND
