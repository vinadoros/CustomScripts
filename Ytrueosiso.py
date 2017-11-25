#!/usr/bin/env python3
"""Inject a TrueOS iso with autoinstall scripts."""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
# Custom includes
# import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Modify TrueOS iso to include autoinstall information.')
parser.add_argument("isopath", help='Path of the existing TrueOS ISO, including the iso name.')
parser.add_argument("injectpath", help='Output Path of the Injected ISO, including the iso name.')
# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get basename and dirname of isopath.
isopath = os.path.abspath(args.isopath)
# baseisoname = os.path.basename(isopath)
# dirisopath = os.path.dirname(isopath)
TrueosInjectedIsoPath = os.path.abspath(args.injectpath)
dirinjectpath = os.path.dirname(TrueosInjectedIsoPath)
baseinjectisoname = os.path.basename(TrueosInjectedIsoPath)
TrueosMountIsoFolder = dirinjectpath + "/trueos_mnt"
TrueosTempIsoFolder = dirinjectpath + "/trueos_tmp"


### Functions ###
def cleanup_isomount():
    """Cleanup iso mount folder."""
    if os.path.isdir(TrueosMountIsoFolder):
        # Unmount.
        subprocess.run("umount -l '{0}'; sudo umount -f '{0}'; sleep 2".format(TrueosMountIsoFolder), shell=True, check=False)
        # Remove Mnt Folder.
        shutil.rmtree(TrueosMountIsoFolder)
def cleanup_tempisofolder():
    """Cleanup temporary iso folder."""
    if os.path.isdir(TrueosTempIsoFolder):
        shutil.rmtree(TrueosTempIsoFolder)

### Begin Code ###
# Remove old Temp Folder.
cleanup_tempisofolder()
os.mkdir(TrueosTempIsoFolder)
cleanup_isomount()
os.mkdir(TrueosMountIsoFolder)
# Change to temp folder.
os.chdir(TrueosTempIsoFolder)
# Copy ISO to temp folder.
subprocess.run("mount -o loop '{0}' '{1}'".format(isopath, TrueosMountIsoFolder), shell=True, check=True)
subprocess.run("rsync -axHAX --info=progress2 --numeric-ids --del '{0}/' '{1}/' ; chmod a+rwx {1}/boot".format(TrueosMountIsoFolder, TrueosTempIsoFolder), shell=True, check=True)
cleanup_isomount()
# Copy the files into the boot folder.
shutil.copy(SCRIPTDIR+"/unattend/pc-autoinstall.conf", TrueosTempIsoFolder+"/boot")
shutil.copy(SCRIPTDIR+"/unattend/pcinstall.cfg", TrueosTempIsoFolder+"/boot")
# Remove old injected ISO if it exists.
if os.path.isfile(TrueosInjectedIsoPath):
    os.remove(TrueosInjectedIsoPath)
# Create new ISO.
subprocess.run("mkisofs -V TRUEOS_INSTALL -J -R -b boot/cdboot -no-emul-boot -o '{0}' '{1}/'".format(TrueosInjectedIsoPath, TrueosTempIsoFolder), shell=True, check=True)
os.chmod(TrueosInjectedIsoPath, 0o777)
# Cleanup temp folder.
cleanup_tempisofolder()
