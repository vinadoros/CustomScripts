#!/usr/bin/env python3

# Python includes.
import os
import grp
import pwd
import sys
import subprocess
import shutil
import stat

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR=sys.path[0]

# Exit if root.
if os.geteuid() == 0:
    sys.exit("\nError: Please run this script as a normal user (not root).\n")

# Get arguments
parser = argparse.ArgumentParser(description='Backup and archive a home folder.')
parser.add_argument("-p", "--provision", help="Provision the VM before starting", action="store_true")

# Save arguments.
args = parser.parse_args()

# Get homefolder.
USERHOME=os.path.expanduser("~")
print("Home Folder is:",USERHOME)

# Ensure that certain commands exist.
cmdcheck = ["xz", "tar", "split", "cat", "id", "megarm", "megals", "megacopy", "openssl", "hostnamectl"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))
