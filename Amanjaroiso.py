#!/usr/bin/env python3
"""Create a Manjaro live-cd."""

# Python includes.
import argparse
import os
import pwd
import shutil
import subprocess
import time
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Exit if not root.
CFunc.is_root(True)

# Get the root user's home folder.
if 'vagrant' in [entry.pw_name for entry in pwd.getpwall()]:
    USERHOME = os.path.expanduser("~vagrant")
else:
    USERHOME = os.path.expanduser("~")

# Get arguments
parser = argparse.ArgumentParser(description='Build Manjaro LiveCD.')
parser.add_argument("-c", "--clean", help='Remove work and output folders', action="store_true")
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-o", "--output", help='Output Location of ISO (default: %(default)s)', default=os.path.join(USERHOME, "iso"))
parser.add_argument("-w", "--workfolder", help='Output and working folder (default: %(default)s)', default=os.path.join(USERHOME, "manjarochroot"))

args = parser.parse_args()

# Process variables
workfolder = os.path.abspath(args.workfolder)
outputfolder = os.path.abspath(args.output)
print("Using work folder {0}.".format(workfolder))
print("Using output folder {0}.".format(outputfolder))
print("Clean: {0}".format(args.clean))

if args.noprompt is False:
    input("Press Enter to continue.")

# Clean.
if args.clean:
    if os.path.isdir(workfolder):
        shutil.rmtree(workfolder)
    if os.path.isdir(outputfolder):
        shutil.rmtree(outputfolder)

# Make folders if missing.
os.makedirs(workfolder, exist_ok=True)
os.makedirs(outputfolder, exist_ok=True)


# https://wiki.manjaro.org/index.php?title=Build_Manjaro_ISOs_with_buildiso
# https://wiki.manjaro.org/index.php?title=Manjaro-tools

# Install necessary packages for building.
CFunc.pacman_install("nano git lsb-release manjaro-tools-iso")

# Clone the iso-profiles repository.
CFunc.gitclone("https://gitlab.manjaro.org/profiles-and-settings/iso-profiles.git", os.path.join(USERHOME, "iso-profiles"))
subprocess.run("buildiso -p xfce -b stable -x -r '{0}' -t '{1}'".format(workfolder, outputfolder), shell=True, check=False)
# Changes
subprocess.run("buildiso -p xfce -cz -r '{0}' -t '{1}'".format(workfolder, outputfolder), shell=True, check=False)
# TODO: Insert check to make sure the ISO built properly.
