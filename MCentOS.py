#!/usr/bin/env python2
"""Install CentOS Software"""

# Includes
import argparse
import grp
import os
import pwd
import subprocess
import sys

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install CentOS Software.')
parser.add_argument("-d", "--docker", help='Install Docker', action="store_true")
parser.add_argument("-r", "--replace", help='Replace distro packages', action="store_true")

# Save arguments.
args = parser.parse_args()

# Get non-root user information.
if os.getenv("SUDO_USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("SUDO_USER")
elif os.getenv("USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR = pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP = grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")


##### Centos Repositories #####

# Install repo tools
subprocess.call("yum install -y yum-utils deltarpm", shell=True)
# EPEL
subprocess.call("yum install -y epel-release", shell=True)
# Software Collections
# https://www.softwarecollections.org
subprocess.call("yum install -y centos-release-scl", shell=True)
subprocess.call("yum-config-manager --enable centos-sclo-rh-testing", shell=True)
if args.replace is True:
    # Centos Plus
    subprocess.call("yum-config-manager --enable centosplus", shell=True)
    # Centos Fasttrack
    subprocess.call("yum-config-manager --enable fasttrack", shell=True)
    # IUS
    # https://ius.io/
    subprocess.call("yum install -y https://centos7.iuscommunity.org/ius-release.rpm", shell=True)
    # EL Repo
    # https://elrepo.org
    subprocess.call("yum install -y http://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm ; yum-config-manager --enable elrepo-extras elrepo-kernel")
    # Fish
    subprocess.call("yum-config-manager --add-repo http://download.opensuse.org/repositories/shells:fish:release:2/CentOS_7/shells:fish:release:2.repo")

# Update system
subprocess.call("yum update -y", shell=True)


##### Centos Software #####

# Install cli tools
subprocess.check_output("yum install -y redhat-lsb-core python34 python34-pip nano tmux iotop rsync openssh-clients p7zip p7zip-plugins zip unzip", shell=True)
subprocess.check_output("yum install -y scl-utils rh-python36", shell=True)
if args.replace is True:
    subprocess.check_output("yum install -y python36u python36u-pip fish", shell=True)

# Replace git and kernel
if args.replace is True:
    subprocess.call("yum swap -y git git2u", shell=True)
    # Bashfish script
    bashfish = subprocess.Popen("scl enable rh-python36 '{0}/CBashFish.py'".format(SCRIPTDIR), shell=True, stdin=None, stdout=None, stderr=None, close_fds=True)
    # Install kernel
    subprocess.check_output("""
    yum install -y kernel-ml kernel-ml-devel kernel-ml-headers
    yum swap -y kernel-tools-libs kernel-ml-tools-libs kernel-ml-tools
    """, shell=True)
else:
    subprocess.check_output("yum install -y git kernel-devel kernel-headers", shell=True)

# Zram
subprocess.check_output("scl enable rh-python36 {0}/Czram.py".format(SCRIPTDIR), shell=True)

# Docker
if args.docker is True:
    subprocess.check_output("scl enable rh-python36 '{0}/CDocker.py -n'".format(SCRIPTDIR), shell=True)

# Virtualbox Additions
subprocess.call("scl enable rh-python36 '{0}/CVBoxGuest.py -n'".format(SCRIPTDIR), shell=True)


##### CentOS Configuration #####
subprocess.check_output("""
# NTP configuration
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Selinux
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux /etc/selinux/config

# Grub configuration
sed -i 's/GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/g' /etc/default/grub
sed -i 's/GRUB_DEFAULT=.*$/GRUB_DEFAULT=0/g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg""", shell=True)

# Wait for processes to finish before exiting.
if args.replace is True:
    bashfish.wait()
