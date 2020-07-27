#!/usr/bin/env python3
"""Create a Manjaro live-cd."""

# Python includes.
import argparse
from datetime import datetime
import os
import shutil
import subprocess
import sys
import time
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Exit if not root.
CFunc.is_root(True)

# Get the root user's home folder.
USERHOME = os.path.expanduser("~root")

# Get arguments
parser = argparse.ArgumentParser(description='Build Manjaro LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolderroot", help='Location of Working Folder (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-o", "--output", help='Output Location of ISO (i.e. {0})'.format(USERHOME), default=USERHOME)
args = parser.parse_args()

# https://wiki.manjaro.org/index.php?title=Build_Manjaro_ISOs_with_buildiso
# https://wiki.manjaro.org/index.php?title=Manjaro-tools

# git clone https://gitlab.manjaro.org/profiles-and-settings/iso-profiles.git ~/iso-profiles
# buildiso -p xfce -b stable -x
# Changes
# buildiso -p xfce -cz