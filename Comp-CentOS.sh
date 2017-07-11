#!/bin/bash

# Get folder of this script
SCRIPTSOURCE="${BASH_SOURCE[0]}"
FLWSOURCE="$(readlink -f "$SCRIPTSOURCE")"
SCRIPTDIR="$(dirname "$FLWSOURCE")"
SCRNAME="$(basename $SCRIPTSOURCE)"
echo "Executing ${SCRNAME}."

# Disable error handlingss
set +eu

# Set user folders.
if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
	export USERNAMEVAR=$SUDO_USER
elif [ "$USER" != "root" ]; then
	export USERNAMEVAR=$USER
else
	export USERNAMEVAR=$(id 1000 -un)
fi
USERGROUP=$(id 1000 -gn)
USERHOME="$(eval echo ~$USERNAMEVAR)"

##### Centos Repositories #####

# Repository options: https://wiki.centos.org/AdditionalResources/Repositories

# Install repo tools
yum install -y yum-utils

# EPEL
yum install -y epel-release

# Centos Plus
yum-config-manager --enable centosplus

# Centos Fasttrack
yum-config-manager --enable fasttrack

# IUS
# https://ius.io/
yum install -y https://centos7.iuscommunity.org/ius-release.rpm

# Software Collections
# https://www.softwarecollections.org
yum install -y centos-release-scl

# EL Repo
# https://elrepo.org
yum install -y http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum-config-manager --enable elrepo-extras elrepo-kernel

# Fish
yum-config-manager --add-repo http://download.opensuse.org/repositories/shells:fish:release:2/CentOS_7/shells:fish:release:2.repo

# Docker
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager --enable docker-ce-edge

yum update -y

##### Centos Software #####

# Install cli tools
yum install -y python34 python34-pip python36u python36u-pip
yum install -y fish tmux iotop rsync p7zip p7zip-plugins zip unzip xdg-utils

# Install kernel
yum install -y kernel-ml kernel-ml-devel

# Install docker
yum install -y docker-ce
systemctl enable docker

# NTP configuration
timedatectl set-local-rtc false
timedatectl set-ntp 1

python3.6 $SCRIPTDIR/Comp-BashFish.py
