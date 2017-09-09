#
# Usage:
# docker build -t vinadoros/ampache .
# docker run -d -t --name ampache  -e 'PORT=443' -v /path:/files -v /path:/var/www vinadoros/ampache
#

FROM debian:latest

# ENV DBPASSWD asdf
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
	apt-get install -y nano git curl apache2 php libapache2-mod-php php-mysql php-curl php-xml php-cli php-curl php-json php-gd composer openssl && \
	a2enmod rewrite && a2enmod ssl && \
	openssl req -x509 -nodes -days 3000 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=US/ST=State/L=City/O=None/CN=www.example.org" && \
	sed -i 's@^upload_max_filesize =.*@upload_max_filesize = 4096M@' /etc/php/7.0/apache2/php.ini

ADD ./ampache_ssl.conf /etc/apache2/sites-enabled/ampache_ssl.conf

VOLUME ["/files"]
VOLUME ["/var/www"]

WORKDIR /var/www

EXPOSE 443

CMD ["apache2ctl","-D","FOREGROUND"]
