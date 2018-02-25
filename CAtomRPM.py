#!/usr/bin/env python3

import os
from datetime import datetime, timedelta
import urllib.request
import platform
import subprocess
import sys

print("Running {0}".format(__file__))

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

MACHINEARCH = platform.machine()

if MACHINEARCH == "x86_64":
    # Cron update script (Fedora specifc)
    CRONSCRIPT = """#!/bin/bash
ATOM_INSTALLED_VERSION=$(rpm -qi atom | grep "Version" |  cut -d ':' -f 2 | cut -d ' ' -f 2)
ATOM_LATEST_VERSION=$(curl -sL "https://api.github.com/repos/atom/atom/releases/latest" | grep -E "https.*atom-amd64.tar.gz" | cut -d '"' -f 4 | cut -d '/' -f 8 | sed 's/v//g')

if [[ $ATOM_INSTALLED_VERSION < $ATOM_LATEST_VERSION ]]; then
  sudo dnf install -y https://github.com/atom/atom/releases/download/v${ATOM_LATEST_VERSION}/atom.x86_64.rpm
fi
"""
    with open('/etc/cron.daily/atomupdate', 'w') as file:
        file.write(CRONSCRIPT)
    os.chmod('/etc/cron.daily/atomupdate', 0o777)

    # Run the cron script to install atom.
    subprocess.run("/etc/cron.daily/atomupdate", shell=True)
else:
    print("Not x86_64, skipping install.")
