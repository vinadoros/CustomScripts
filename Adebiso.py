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

print("Running {0}".format(__file__))

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
USERHOME=os.path.expanduser("~")
MACHINEARCH = platform.machine()

# Get arguments
parser = argparse.ArgumentParser(description='Build Debian LiveCD.')
parser.add_argument("-w", "--rootworkfolder", help='Location of Working Folder (i.e. /home/user)', default=USERHOME)
parser.add_argument("-n", "--noprompt",help='Do not prompt.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:",args.desktop)

# Exit if not root.
if not os.geteuid() == 0:
    sys.exit("\nError: Please run this script as root.\n")
