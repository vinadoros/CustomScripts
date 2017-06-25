#!/bin/bash
set -e

# Set unset variables to defaults
[ -z $USER_PASSWORD ] && USER_PASSWORD=asdf

# Install common software
apt-get update
apt-get install -y vim sudo wget nano net-tools iproute2
apt-get install -y firefox chromium-browser chromium-codecs-ffmpeg
apt-get install -y xfce4 xterm xfce4-terminal xubuntu-default-settings
apt-get purge -y pm-utils xscreensaver*
apt-get clean

# Add users
adduser --disabled-password -uid 1000 --gecos "" user
echo "root:$USER_PASSWORD" | chpasswd
echo "user:$USER_PASSWORD" | chpasswd
usermod -aG sudo,video,disk,tty user
