#
# Usage:
# docker build -t vinadoros/koel .
# docker run -d -t --restart=always --name koel  -e 'PORT=443' -e 'DBPASSWD=asdf' -e 'ADMINPASS=asdf' -p 443:443 -v /path:/files -v /path:/var/www -v /path:/var/lib/mysql vinadoros/koel
#

FROM arm32v7/ubuntu:rolling

# Enable this to build the arm image on x86-64.
# Enable binfmt-support on host machine (to tell the kernel to translate the binaries).
# Copy qemu-arm-static binary into this folder, and enable this line.
# COPY qemu-arm-static /usr/bin/qemu-arm-static

# Environment variables
ENV DEBIAN_FRONTEND="noninteractive" PORT="443" DBPASSWD="pass" ADMINPASS="pass"

# Install stock packages.
RUN apt-get update && \
	apt-get install -y nano git curl gnupg nginx php-fpm php-mysql php-curl php-xml php-cli php-curl php-json php-gd php-mbstring php-zip composer openssl mariadb-client mariadb-server

# Install external packages
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
		curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
		echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
		apt-get update && \
		apt-get install -y nodejs yarn build-essential g++

# Configuration
RUN	openssl req -x509 -nodes -days 3000 -newkey rsa:2048 -keyout /etc/ssl/selfsigned.key -out /etc/ssl/selfsigned.crt -subj "/C=US/ST=State/L=City/O=None/CN=www.example.org" && \
		rm -f /etc/localtime; ln -s /usr/share/zoneinfo/America/New_York /etc/localtime && \
		sed -i 's@^upload_max_filesize =.*@upload_max_filesize = 4096M@' /etc/php/7.0/fpm/php.ini && \
		sed -i 's@^post_max_size =.*@post_max_size = 4096M@' /etc/php/7.0/fpm/php.ini && \
		# fix: *** stack smashing detected ***: nginx: worker process terminated / [alert] 9#9: worker process *process-id* exited on signal 6
		sed -i "s/worker_processes auto;/worker_processes 1;/g" /etc/nginx/nginx.conf

# Add scripts
COPY . /
RUN mv /koel_nginx.conf /etc/nginx/sites-enabled/ && \
		rm -f /etc/nginx/sites-enabled/default && \
		chmod a+rwx /startup.sh

# Volumes
VOLUME ["/files", "/var/www", "/var/lib/mysql"]

WORKDIR /var/www
EXPOSE $PORT

CMD ["/startup.sh"]
