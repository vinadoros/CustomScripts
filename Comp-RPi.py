#!/usr/bin/env python3

# Python includes.
import argparse
from datetime import datetime, timedelta
import grp
import os
import platform
import pwd
import shutil
import subprocess
import sys
import urllib.request

# OmxPlayer from http://omxplayer.sconde.net/
OMXURL = "http://omxplayer.sconde.net/builds/omxplayer_0.3.7~git20170130~62fb580_armhf.deb"

print("Running {0}".format(__file__))
print("This script is for use only on Ubuntu.")

# Get arguments
parser = argparse.ArgumentParser(description='Install Raspberry Pi stuff.')
parser.add_argument("-d", "--docker", help='Install docker', action="store_true")
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-o", "--omxdeb", help='Install OMXPlayer.', action="store_true")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
if os.getenv("SUDO_USER") != None and os.getenv("SUDO_USER") != "root":
    USERNAMEVAR=os.getenv("SUDO_USER")
elif os.getenv("USER") != "root":
    USERNAMEVAR=os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR=pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP=grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
USERHOME=os.path.expanduser("~{0}".format(USERNAMEVAR))
MACHINEARCH = platform.machine()
print("Username is:",USERNAMEVAR)
print("Group Name is:",USERGROUP)

# Print detected options
print(args)

if args.noprompt is False:
    input("Press Enter to continue.")
