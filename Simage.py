#!/usr/bin/env python3
"""Backup, mount, and restore disk images."""

# Python includes.
import argparse
from datetime import datetime
import os
import stat
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Ubuntu Software.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-x", "--xz", help='Use tar with xz.', action="store_true")
parser.add_argument("-s", "--squash", help='Use squashfs with xz.', action="store_true")
parser.add_argument("-b", "--backup", help='Backup the given block device.', action="store_true")
parser.add_argument("-r", "--restore", help='Restore the image to the given block device.', action="store_true")
parser.add_argument("-d", "--blockdevice", help='A block device for use with backup and restore.')
parser.add_argument("-i", "--image", help='A backup or mountable file.')
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

### Sanity Checks ###
# Check backup and restore options.
if args.backup and args.restore:
    sys.exit("\nERROR: Both backup and restore mode selected. Exiting.")
elif args.backup:
    print("Backup Mode.")
elif args.restore:
    print("Restore Mode.")
elif not args.backup and not args.restore:
    sys.exit("\nERROR: No mode (backup, restore) selected. Exiting.")
if args.backup or args.restore:
    if stat.S_ISBLK(os.stat(args.blockdevice).st_mode) is True:
        print("Using block device {0}.".format(args.blockdevice))
if args.restore and os.path.isfile(args.image):
    print("Restoring file {0} to {1}.".format(args.image, args.blockdevice))
elif args.restore and not os.path.isfile(args.image):
    sys.exit("\nERROR: Restore mode does not have a valid file selected. Exiting.")
# Check the compression settings.
if not args.xz and not args.squash:
    print("Using raw mode. No squashfs or tar.xz.")
elif args.xz and args.squash:
    sys.exit("\nERROR: Both squash and tar.xz mode selected. Exiting.")
elif args.xz:
    print("Using tar.xz mode.")
elif args.squash:
    print("Using squash mode.")
# Prompt before proceeding.
if args.noprompt is False:
    input("Press Enter to continue.")

### Functions ###
def cleanup():
    """Perform cleanup tasks at end of script or after termination"""
    print("\nPerforming Cleanup.")
def backup_xz():
    """Backup a block device to an xz compressed image."""
def backup_squash():
    """Backup a block device to a squash image."""
def backup_raw():
    """Backup a block device to a raw image."""
def restore_xz():
    """Backup a block device to an xz compressed image."""
def restore_squash():
    """Backup a block device to a squash image."""
def restore_raw():
    """Backup a block device to a raw image."""

### Begin Code ###
# Save start time.
beforetime = datetime.now()
try:
    print("Begin Code")
    ### Backup Section ###

    ### Restore Section ###

finally:
    cleanup()
finishtime = datetime.now()
print("Completed in :", finishtime - beforetime)
print("Script ended at {0}.".format(finishtime))
