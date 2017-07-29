#
# Usage:
# docker build -t vinadoros/koel .
# docker run -d -t --name koel  -e 'PORT=443' -e 'DBPASSWD=asdf' -p 443:443 -v /path:/files -v /path:/var/www -v /path:/var/lib/mysql vinadoros/koel
#

FROM arm32v7/ubuntu:rolling

# Enable this to build on x86-64.
# Copy qemu-arm-static binary into this folder, and enable this line.
# COPY qemu-arm-static /usr/bin/qemu-arm-static

# Environment variables
ENV DEBIAN_FRONTEND noninteractive
ENV PORT 443
ENV DBPASSWD pass

# Install stock packages.
RUN apt-get update && \
	apt-get install -y nano git curl gnupg apache2 php libapache2-mod-php php-mysql php-curl php-xml php-cli php-curl php-json php-gd php-mbstring php-zip composer openssl mariadb-client mariadb-server supervisor

# Install external packages
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
		curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
		echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
		apt-get update && \
		apt-get install -y nodejs yarn build-essential g++

# Configuration
RUN	a2enmod rewrite && a2enmod ssl && \
		openssl req -x509 -nodes -days 3000 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=US/ST=State/L=City/O=None/CN=www.example.org" && \
		sed -i 's@^upload_max_filesize =.*@upload_max_filesize = 4096M@' /etc/php/7.0/apache2/php.ini

# Add scripts
COPY . /
RUN mv /koel_ssl.conf /etc/apache2/sites-enabled/ && \
		chmod a+rwx /koel_setup.sh /mariadb_setup.sh

# Volumes
VOLUME ["/files"]
VOLUME ["/var/www"]
VOLUME ["/var/lib/mysql"]

WORKDIR /var/www
EXPOSE $PORT

CMD ["supervisord","-c","/svd_koel.conf"]
# CMD ["bash"]
