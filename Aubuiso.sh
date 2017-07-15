#!/usr/bin/env bash

# First, set up the build tools and workspace.
# The scripts require that you work in /build

apt-get install -y genisoimage syslinux-utils # tools for generate ISO image
apt-get install -y memtest86+ syslinux syslinux-themes-ubuntu-xenial gfxboot-theme-ubuntu

# apt-get install -y livecd-rootfs
cp -a /usr/share/livecd-rootfs/live-build/auto .

# All the hard work is done with live-build (lb command)
# and we have to configure it with environment variables

export SUITE=zesty
export ARCH=amd64
export PROJECT=base
export MIRROR=http://archive.ubuntu.com/ubuntu/
export mirror_url=http://archive.ubuntu.com/ubuntu/
export BINARYFORMAT=iso-hybrid
export LB_SYSLINUX_THEME=ubuntu-xenial

# Now we can have live-build set up the workspace
lb config --initramfs-compression=gzip 

# lb config --mode ubuntu --distribution zesty --keyring-packages ubuntu-keyring --binary-images iso-hybrid
# lb config --parent-debian-installer-distribution zesty --parent-distribution zesty
# lb config --archive-areas "main restricted universe multiverse"
# lb config --parent-archive-areas "main restricted universe multiverse"
# lb config --parent-mirror-bootstrap $mirror_url --parent-mirror-binary $mirror_url --parent-mirror-chroot $mirror_url --parent-mirror-chroot-security $mirror_url --parent-mirror-binary-security $mirror_url --parent-mirror-debian-installer $mirror_url
# lb config --mirror-debian-installer $mirror_url
# lb config --mirror-binary $mirror_url --mirror-binary-security $mirror_url
# lb config --mirror-bootstrap $mirror_url
# lb config --mirror-chroot $mirror_url --mirror-chroot-security $mirror_url
# lb config --initramfs live-boot
# lb config --bootappend-live "boot=live union=overlay config username=user hostname=$debian_dist"
# lb config --linux-flavours generic
# lb config --syslinux-theme "ubuntu-xenial"
# And finally, start the build
lb build
