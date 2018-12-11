#!/usr/bin/env python3
"""Create an live-cd using a virtual environment."""

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

# Folder of this script
SCRIPTDIR = sys.path[0]


### Functions ###
def docker_setup():
    return
def docker_runcmd():
    return
def docker_destroy():
    return


# Exit if not root.
CFunc.is_root(True)

# Get arguments
parser = argparse.ArgumentParser(description='Build LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolder", help='Location of Working Folder')
parser.add_argument("-t", "--type", help='1=Ubuntu, 2=Fedora, 3=Debian')
parser.add_argument("-r", "--release", help='Release of LiveCD')

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolder)
print("Using work folder {0}.".format(buildfolder))
print("Type: {0}".format(args.type))
print("Release: {0}".format(args.release))

if args.noprompt is False:
    input("Press Enter to continue.")

