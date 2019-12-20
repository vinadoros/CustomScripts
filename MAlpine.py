#!/usr/bin/env python3
"""Install Alpine Software"""

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
parser = argparse.ArgumentParser(description='Install Alpine Software.')
parser.add_argument("-d", "--desktop", help='Desktop Environment (i.e. gnome, kde, mate, etc)')
parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)

# Exit if not root.
CFunc.is_root(True)


# Repos
with open(os.path.join(os.sep, "etc", "apk", "repositories"), 'w') as f:
    f.write('http://dl-cdn.alpinelinux.org/alpine/latest-stable/main/\nhttp://dl-cdn.alpinelinux.org/alpine/latest-stable/community/')
