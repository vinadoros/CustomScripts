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
if shutil.which("apm") is None:
    sys.exit("\nError: Atom editor not detected. Please install atom.\n")

# Get homefolder.
USERHOME = os.path.expanduser("~")
print("Home Folder is:", USERHOME)

# Update existing plugins
subprocess.call("apm update", shell=True)
# Install atom plugins
# Python plugins
subprocess.call("apm install autocomplete-python", shell=True)
# Git plugins
subprocess.call("apm install git-plus git-time-machine", shell=True)
# Sublime column editing
subprocess.call("apm install sublime-style-column-selection", shell=True)

### Plugins which require external packages ###
# Linting
subprocess.call("apm install linter", shell=True)
# Python
subprocess.call("apm install autocomplete-python linter-python", shell=True)
# Shell
subprocess.call("apm install linter-shellcheck", shell=True)
# Php
subprocess.call("apm install linter-php", shell=True)
# C
subprocess.call("apm install linter-gcc", shell=True)

print("Be sure to install php, gcc, python3-jedi, pylama, pylama-pylint, shellcheck")
