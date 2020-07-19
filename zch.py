#!/usr/bin/env python3
"""Enter chroot"""

# Python includes.
import argparse
import os
import shutil
import sys
import subprocess
# Custom includes
import CFunc

# Folder of this script
SCRIPTDIR = sys.path[0]

### Functions ###
def ChrootMountPaths(RootPath):
    """Mount all binds for chroot"""
    subprocess.run("mount --rbind /dev {0}/dev".format(RootPath), shell=True, check=True)
    subprocess.run("mount --make-rslave {0}/dev".format(RootPath), shell=True, check=True)
    subprocess.run("mount -t proc /proc {0}/proc".format(RootPath), shell=True, check=True)
    subprocess.run("mount --rbind /sys {0}/sys".format(RootPath), shell=True, check=True)
    subprocess.run("mount --make-rslave {0}/sys".format(RootPath), shell=True, check=True)
    subprocess.run("mount --rbind /tmp {0}/tmp".format(RootPath), shell=True, check=True)
    shutil.copy(os.path.join(os.sep, "etc", "resolv.conf"), os.path.join(RootPath, "etc", "resolv.conf"))
def ChrootUnmountPaths(RootPath):
    """Unmount all binds for chroot"""
    subprocess.run("umount -l {0}/dev".format(RootPath), shell=True, check=False, stdout=subprocess.DEVNULL)
    subprocess.run("umount -l {0}/proc".format(RootPath), shell=True, check=False, stdout=subprocess.DEVNULL)
    subprocess.run("umount -l {0}/sys".format(RootPath), shell=True, check=False, stdout=subprocess.DEVNULL)
    subprocess.run("umount -l {0}/tmp".format(RootPath), shell=True, check=False, stdout=subprocess.DEVNULL)
def ChrootSingleCommand(RootPath, command):
    """Run a single command in the chroot."""
    ChrootMountPaths(RootPath)
    subprocess.run("PATH=$PATH:/sbin:/bin:/usr/sbin:/usr/local/bin chroot {0} {1}".format(RootPath, command), shell=True, check=False)
    ChrootUnmountPaths(RootPath)


# Exit if not root.
CFunc.is_root(True)

if __name__ == '__main__':
    print("Running {0}".format(__file__))

    # Get arguments
    parser = argparse.ArgumentParser(description='Enter a chroot.')
    parser.add_argument("chrootpath", help='Path to enter the chroot')
    parser.add_argument("-c", "--chrootcommand", default="/bin/bash", help='Command to run in the chroot')
    args = parser.parse_args()

    # Get absolute path of the given path.
    abschrootpath = os.path.realpath(args.chrootpath)
    ChrootSingleCommand(abschrootpath, args.chrootcommand)
