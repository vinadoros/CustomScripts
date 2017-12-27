#!/usr/bin/env python3
"""Install systemd-cron-next"""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Compile and install systemd-cron-next.')
parser.add_argument("-r", "--rust", help='Install rust from upstream.', action="store_true")
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")


### Functions ###
def folder_remove(folderpath):
    """Remove folder if it exists"""
    if os.path.isdir(folderpath):
        shutil.rmtree(folderpath)


### Install dependencies ###
# Rust
if args.rust is True:
    print("Installing rust from upstream.")
    subprocess.run("curl https://sh.rustup.rs -sSf | sh -s -- -y", shell=True)
    if not shutil.which("rustc"):
        sys.exit("\nShell must be reloaded to add rustc to path. Please re-run script after reloading the shell.")
elif shutil.which("dnf"):
    CFunc.dnfinstall("rust cargo")
elif shutil.which("apt-get"):
    CFunc.aptinstall("rustc cargo")
# Extra dependancies
if shutil.which("dnf"):
    # Install run-parts
    CFunc.dnfinstall("crontabs")
elif shutil.which("apt-get"):
    # Install run-parts
    CFunc.aptinstall("debianutils")

# Check for dependancies
cmdcheck = ["run-parts", "rustc"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

# Disable cron
cron_services = "cron anacron crond"
subprocess.run("systemctl disable {0}; systemctl stop {0}".format(cron_services), shell=True, check=False)


### Compile from source ###
gitfolderpath = "/var/tmp/systemd-cron-next"
folder_remove(gitfolderpath)
# Clone source
subprocess.run("git clone https://github.com/systemd-cron/systemd-cron-next {0}".format(gitfolderpath), shell=True, check=True)
subprocess.run("cd {0}; ./configure --enable-persistent=yes; make; make install".format(gitfolderpath), shell=True, check=True)
# Ensure reboot scripts don't trigger immediately.
subprocess.run("touch /run/crond.reboot /run/crond.bootdir", shell=True)
# Enable service
subprocess.run("systemctl daemon-reload; systemctl enable cron.target; sleep 1; systemctl status cron.target", shell=True)
# Cleanup
folder_remove(gitfolderpath)
