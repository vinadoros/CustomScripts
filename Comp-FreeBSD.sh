#!/bin/sh

# Assume yes for pkg.
export ASSUME_ALWAYS_YES=yes

# Update freebsd.
freebsd-update -F fetch install
# Update packages.
pkg update -f

# Install command line utilities.
pkg install -y nano fish git

# Install mate.
pkg install -y xorg xf86-video-fbdev mate-desktop mate
sysrc moused_enable=yes dbus_enable=yes hald_enable=yes
# Slim display manager
pkg install -y slim
sysrc slim_enable=yes
