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

# Install kernel and firmware.
apt install -y linux-image-generic linux-headers-generic linux-firmware memtest86+

# Livecd packages
apt install -y lupin-casper casper

# Install extra packages.
apt install -y mate-desktop-environment

# Clean up
apt-get clean

"""
chrootscriptfile = chrootfolder+"/livescript.sh"
print("Writing {0}".format(chrootscriptfile))
with open(chrootscriptfile, 'w') as chrootscriptfile_write:
    chrootscriptfile_write.write(CHROOTSCRIPT)
os.chmod(chrootscriptfile, 0o777)
# Run chroot script
subprocess.run("{0}/zch.py {1} -c {2}".format(SCRIPTDIR, chrootfolder, "/livescript.sh"), shell=True)


# Live CD Preperation
subprocess.run("""#!/bin/bash -ex
cd {0}
mkdir -p {0}/image/{casper,isolinux,install}

# Copy the kernel and initrd
cp -a {0}/chroot/boot/vmlinuz-*-generic {0}/image/casper/vmlinuz
cp -a {0}/chroot/boot/initrd.img-*-generic {0}/image/casper/initrd.lz
cp /usr/lib/ISOLINUX/isolinux.bin {0}/image/isolinux/
cp {0}/chroot/boot/memtest86+.bin {0}/image/install/memtest

# Create manifset
chroot {0}/chroot dpkg-query -W --showformat='${Package} ${Version}\n' | tee {0}/image/casper/filesystem.manifest

# Create squash image
mksquashfs {0}/chroot {0}/image/casper/filesystem.squashfs -e boot
printf $(du -sx --block-size=1 {0}/chroot | cut -f1) > image/casper/filesystem.size

touch {0}/image/ubuntu
mkdir {0}/image/.disk
cd {0}/image/.disk
touch base_installable
echo "full_cd/single" > cd_type
echo "Ubuntu Remix 14.04" > info  # Update version number to match your OS version
echo "http//your-release-notes-url.com" > release_notes_url
cd {0}

# Generate md5sum
cd image && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt

""".format(buildfolder), shell=True)


# Bootloader configuration
BLCONFIG = """DEFAULT live
LABEL live
  menu label ^Start or install Ubuntu Remix
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd.lz quiet splash --
LABEL check
  menu label ^Check CD for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd.lz quiet splash --
LABEL memtest
  menu label ^Memory test
  kernel /install/memtest
  append -
LABEL hd
  menu label ^Boot from first hard disk
  localboot 0x80
  append -
DISPLAY isolinux.txt
TIMEOUT 20
PROMPT 1
"""
blconfigfile = buildfolder+"/image/isolinux/isolinux.cfg"
print("Writing {0}".format(blconfigfile))
with open(blconfigfile, 'w') as blconfigfile_write:
    blconfigfile_write.write(BLCONFIG)
