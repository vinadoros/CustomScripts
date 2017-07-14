#!/usr/bin/env bash

# First, set up the build tools and workspace.
# The scripts require that you work in /build

apt-get install -y genisoimage syslinux-utils # tools for generate ISO image
apt-get install -y memtest86+ syslinux syslinux-themes-ubuntu-xenial gfxboot-theme-ubuntu

apt-get install -y livecd-rootfs
cp -a /usr/share/livecd-rootfs/live-build/auto .

# All the hard work is done with live-build (lb command)
# and we have to configure it with environment variables

export SUITE=xenial
export ARCH=amd64
export PROJECT=ubuntu
export MIRROR=http://archive.ubuntu.com/ubuntu/
export BINARYFORMAT=iso-hybrid
export LB_SYSLINUX_THEME=ubuntu-xenial

# Now we can have live-build set up the workspace

lb config noauto --mode ubuntu --distribution xenial --keyring-packages ubuntu-keyring --binary-images iso-hybrid --memtest memtest86+ --source false --build-with-chroot false --parent-mirror-bootstrap http://archive.ubuntu.com/ubuntu/ --apt-source-archives false --initsystem none --bootloader syslinux --zsync=false --initramfs-compression=gzip

# And finally, start the build
lb build
