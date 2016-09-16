#!/usr/bin/env python3

import os
import shutil
import subprocess
import sys

print("Running {0}".format(__file__))

# Exit if root.
if os.geteuid() == 0:
    sys.exit("\nError: Please run this script as a normal user (not root).\n")

# Exit if atom not installed.
if shutil.which("apm") == None:
    sys.exit("\nError: Atom editor not detected. Please install atom.\n")

# Get homefolder.
USERHOME=os.path.expanduser("~")
print("Home Folder is:",USERHOME)

# Install atom plugins
# Python plugins
subprocess.call("apm install autocomplete-python", shell=True)
# Git plugins
subprocess.call("apm install git-plus git-time-machine", shell=True)
