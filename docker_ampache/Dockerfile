#
# Usage:
# docker build -t vinadoros/ampache .
# docker run -d -t --restart=always --name ampache -v /path:/files vinadoros/ampache
#

FROM debian:latest

ENV DEBIAN_FRONTEND="noninteractive" PROXY_PORT="443" ADMINPASS="password"

RUN apt-get update && \
	apt-get install -y nano git unzip curl apache2 php libapache2-mod-php php-mysql php-curl php-xml php-cli php-curl php-json php-gd php-zip composer openssl mariadb-client && \
	a2enmod rewrite && a2enmod ssl && \
	openssl req -x509 -nodes -days 3000 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=US/ST=State/L=City/O=None/CN=www.example.org" && \
	sed -i 's@^upload_max_filesize =.*@upload_max_filesize = 4096M@' /etc/php/7.0/apache2/php.ini && \
	sed -i 's@^post_max_size =.*@post_max_size = 4096M@' /etc/php/7.0/apache2/php.ini

ADD ./ampache_ssl.conf /etc/apache2/sites-enabled/ampache_ssl.conf
ADD ./startup.sh /startup.sh
RUN chmod a+rwx /startup.sh

VOLUME ["/files"]

WORKDIR /var/www

EXPOSE 443

CMD ["/startup.sh"]
