#
# Usage:
# docker build -t vinadoros/koel .
# docker run -d -t --name koel  -e 'PORT=443' -v /path:/files -v /path:/var/www vinadoros/koel
#

FROM arm32v7/ubuntu:latest

ENV PORT 443
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
	apt-get install -y nano git curl apache2 php libapache2-mod-php php-mysql php-curl php-xml php-cli php-curl php-json php-gd php-mbstring php-zip composer openssl mysql-client && \
	curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
	apt-get install -y nodejs build-essential g++ && \
	a2enmod rewrite && a2enmod ssl && \
	openssl req -x509 -nodes -days 3000 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt -subj "/C=US/ST=State/L=City/O=None/CN=www.example.org" && \
	sed -i 's@^upload_max_filesize =.*@upload_max_filesize = 4096M@' /etc/php/7.0/apache2/php.ini

ADD ./koel_ssl.conf /etc/apache2/sites-enabled/koel_ssl.conf
ADD ./startup.sh /startup.sh
RUN chmod a+rwx /startup.sh

ENV DBPASSWD pass

VOLUME ["/files"]
VOLUME ["/var/www"]

WORKDIR /var/www

EXPOSE $PORT

CMD ["/startup.sh"]
# CMD ["apache2ctl","-D","FOREGROUND"]
