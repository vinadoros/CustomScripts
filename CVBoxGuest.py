#!/usr/bin/env python3
"""Install Virtualbox for guest machine"""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
import urllib.request
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Virtualbox Guest Software.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-f", "--force", help='Force installation.', action="store_true")
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)

# Get VM State
vmstatus = CFunc.getvmstate()

# Detect major virtualbox version
vboxver_url = "http://download.virtualbox.org/virtualbox/LATEST.TXT"
vboxver_data = urllib.request.urlopen(vboxver_url)
vboxfullver = vboxver_data.read().decode().strip()
print("Virtualbox version is {0}.".format(vboxfullver))
vboxguesturl = "http://download.virtualbox.org/virtualbox/{0}/VBoxGuestAdditions_{0}.iso".format(vboxfullver)
print("Guest additions are located at {0}".format(vboxguesturl))

# Detect OS information
distro, release = CFunc.detectdistro()
print("Distro is {0}.".format(distro))
print("Release is {0}.".format(release))

### Functions ###
def cleanup_isopath(isopath):
    """Remove isopath if it exists"""
    if os.path.isdir(isopath):
        shutil.rmtree(isopath)


if vmstatus != "vbox" and args.force is False:
    sys.exit("\nERROR: Machine is not running in a VirtualBox guest. Exiting.")

if args.noprompt is False:
    input("Press Enter to continue.")


### Install Virtualbox Guest Additions ###
# Install distro pre-requisites
if distro == "Ubuntu":
    CFunc.aptinstall("build-essential dkms")
elif distro == "Fedora":
    CFunc.dnfinstall("gcc dkms make bzip2 perl kernel-devel")
elif distro == "CentOS":
    subprocess.run("yum install -y gcc dkms make bzip2 perl", shell=True)

# Download and Extract Guest Additions
guestiso_rootfolder = "/var/tmp"
guestiso_folder = guestiso_rootfolder + "/vbox"
# Check if iso was uploaded by packer.
if os.path.isfile("/root/VBoxGuestAdditions.iso"):
    guestiso_filepath = "/root/VBoxGuestAdditions.iso"
else:
    # Download the iso if not detected.
    guestisodl = CFunc.downloadfile(vboxguesturl, guestiso_rootfolder)
    guestiso_filepath = guestisodl[0]
cleanup_isopath(guestiso_folder)
# Extract iso
subprocess.run("7z x {0} -o{1}".format(guestiso_filepath, guestiso_folder), shell=True)
# Run the vbox installer
subprocess.run("chmod a+rwx -R {0}; {0}/VBoxLinuxAdditions.run".format(guestiso_folder), shell=True)
# Add user to group
subprocess.run("gpasswd -a {0} vboxsf".format(USERNAMEVAR), shell=True)
# Cleanup
cleanup_isopath(guestiso_folder)
