#
# Usage:
# docker build -t vinadoros/landingpage .
# docker run -d -t --restart=always --name landingpage -p 443:443 vinadoros/landingpage
#

FROM nginx

# Environment variables
ENV DEBIAN_FRONTEND="noninteractive"

# Install stock packages.
RUN apt-get update && \
	apt-get install -y nano openssl

# Configuration
RUN	openssl req -x509 -nodes -days 3000 -newkey rsa:2048 -keyout /etc/ssl/selfsigned.key -out /etc/ssl/selfsigned.crt -subj "/C=US/ST=State/L=City/O=None/CN=www.example.org" && \
		rm -f /etc/localtime; ln -s /usr/share/zoneinfo/America/New_York /etc/localtime

# Add scripts
COPY landingpage.conf /etc/nginx/nginx.conf
COPY LandingPage.html /usr/share/nginx/html

EXPOSE 443
