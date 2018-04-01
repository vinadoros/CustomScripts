#!/bin/sh

# Assume yes for pkg.
export ASSUME_ALWAYS_YES=yes

# Update freebsd.
freebsd-update --not-running-from-cron fetch install
# Update packages.
pkg update -f

# Update/Install ports
# portsnap auto

# Install command line utilities.
pkg install -y nano bash zsh git sudo python3
echo "%wheel ALL=(ALL) ALL" > /usr/local/etc/sudoers.d/10-wheel

# Install mate.
pkg install -y xorg xorg-drivers mate-desktop mate
sysrc moused_enable=yes dbus_enable=yes hald_enable=yes
# Slim display manager
pkg install -y slim
sysrc slim_enable=yes
echo "exec mate-session" > /root/.xinitrc

# Set default VM guest variables
pkg install -y dmidecode
set PRODUCTNAME=`dmidecode -s baseboard-product-name`
if PRODUCTNAME="VirtualBox"; then
  set VBOXGUEST=1
  pkg install -y virtualbox-ose-additions
  sysrc vboxguest_enable=yes vboxservice_enable=yes
else
  set VBOXGUEST=0
fi
if PRODUCTNAME="VMware"; then
  set VMWGUEST=1
else
  set VMWGUEST=0
fi
