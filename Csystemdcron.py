#!/usr/bin/env python3
"""Install systemd-cron-next"""

# Python includes.
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")


### Functions ###
def folder_remove(folderpath):
    """Remove folder if it exists"""
    if os.path.isdir(folderpath):
        shutil.rmtree(folderpath)


### Install dependencies ###
if shutil.which("dnf"):
    print("Installing Fedora requirements.")
    # Rust dependencies
    CFunc.dnfinstall("rust cargo")
    # Install run-parts
    CFunc.dnfinstall("crontabs")
elif shutil.which("apt-get"):
    print("Installing Ubuntu requirements.")
    CFunc.aptinstall("")
# Disable cron
cron_services = "cron anacron crond"
subprocess.run("systemctl disable {0}; systemctl stop {0}".format(cron_services), shell=True, check=False)


### Compile from source ###
gitfolderpath = "/var/tmp/systemd-cron-next"
folder_remove(gitfolderpath)
# Clone source
subprocess.run("git clone https://github.com/systemd-cron/systemd-cron-next {0}".format(gitfolderpath), shell=True)
subprocess.run("cd {0}; ./configure --enable-persistent=yes; make; make install", shell=True)
# Enable service
subprocess.run("systemctl daemon-reload; systemctl enable cron.target", shell=True)
# Cleanup
folder_remove(gitfolderpath)
