#!/usr/bin/env python3

# Python includes.
import argparse
import os
import sys
import subprocess

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Enter a chroot.')
parser.add_argument("chrootpath", help='Path to enter the chroot')
parser.add_argument("-c", "--chrootcommand", default="/bin/bash", help='Command to run in the chroot')

# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get absolute path of the given path.
abschrootpath = os.path.realpath(args.chrootpath)

subprocess.run("""
mount --rbind /dev {0}/dev
mount --make-rslave {0}/dev
mount -t proc /proc {0}/proc
mount --rbind /sys {0}/sys
mount --make-rslave {0}/sys
mount --rbind /tmp {0}/tmp
cp /etc/resolv.conf {0}/etc/resolv.conf
PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/local/bin
chroot {0} {1}
umount -l {0}/dev > /dev/null &
umount -l {0}/proc > /dev/null &
umount -l {0}/sys > /dev/null &
umount -l {0}/tmp > /dev/null &
""".format(abschrootpath, args.chrootcommand), shell=True)
