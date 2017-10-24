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

# Atom variables
ATOMRPMFILE = "/tmp/atom.x86_64.rpm"
ATOMRPMURL = "https://atom.io/download/rpm"

# Find version on GitHub
github_link = subprocess.run("""curl -I https://github.com/atom/atom/releases/latest | perl -n -e '/^Location: (.*)$/ && print "$1"'""", shell=True, stdout=subprocess.PIPE, universal_newlines=True)
version_available = subprocess.run("""basename {0} | perl -n -e '/(\d+.\d+.\d+)/ && print "$1"'""".format(github_link.stdout.strip()), shell=True, stdout=subprocess.PIPE, universal_newlines=True)
version_available = version_available.stdout.strip()
print("Version available:", version_available)
version_installed = subprocess.run("""rpm -q atom | perl -n -e '/atom-(.*?)-/ && print "$1"'""", shell=True, stdout=subprocess.PIPE, universal_newlines=True)
version_installed = version_installed.stdout.strip()
print("Version installed:", version_installed)
if version_available != version_installed and MACHINEARCH == "x86_64":
    print("Downloading", ATOMRPMURL, "to", ATOMRPMFILE)
    urllib.request.urlretrieve(ATOMRPMURL, ATOMRPMFILE)
    # Install it.
    subprocess.run("rpm -ivh {0}".format(ATOMRPMFILE), shell=True)
    os.remove(ATOMRPMFILE)
else:
    print("Versions are equal, skipping install.")
