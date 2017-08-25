#!/usr/bin/env python3

# Python includes.
import argparse
from datetime import datetime
import glob
import os
import shutil
import subprocess
import sys
import time

print("Running {0}".format(__file__))
# Folder of this script
SCRIPTDIR = sys.path[0]

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

USERHOME = "/root"

# Get arguments
parser = argparse.ArgumentParser(description='Build Ubuntu LiveCD.')
parser.add_argument("-n", "--noprompt",help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolderroot", help='Location of Working Folder (i.e. {0})'.format(USERHOME), default=USERHOME)
parser.add_argument("-o", "--output", help='Output Location of ISO (i.e. {0})'.format(USERHOME), default=USERHOME)

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolderroot+"/ubuiso_buildfolder")
print("Root of Working Folder:",buildfolder)
outfolder = os.path.abspath(args.output)
print("ISO Output Folder:",outfolder)
if not os.path.isdir(outfolder):
    sys.exit("\nError, ensure {0} is a folder.".format(outfolder))

if args.noprompt is False:
    input("Press Enter to continue.")

# Make the build folder if it doesn't exist
os.makedirs(buildfolder, 0o777, exist_ok=True)

# Create chroot folder
chrootfolder = buildfolder+"/chroot"
os.makedirs(chrootfolder, 0o777, exist_ok=True)

# Install ubuntu in chroot
subprocess.run("{0}/BDebian.py -t ubuntu -r {1} -nz -g 1 {2}".format(SCRIPTDIR, "zesty", chrootfolder), shell=True)

# Additional chroot script
CHROOTSCRIPT = """#!/bin/bash -ex
export DEBIAN_FRONTEND=noninteractive

apt install -y linux-image-generic linux-headers-generic
apt install -y mate-desktop-environment

"""
chrootscriptfile = chrootfolder+"/livescript.sh"
print("Writing {0}".format(chrootscriptfile))
with open(chrootscriptfile, 'w') as chrootscriptfile_write:
    chrootscriptfile_write.write(CHROOTSCRIPT)
os.chmod(chrootscriptfile, 0o777)
# Run chroot script
subprocess.run("{0}/zch.py {1} -c {2}".format(SCRIPTDIR, chrootfolder, "/livescript.sh"), shell=True)
