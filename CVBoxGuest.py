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
parser.add_argument("-f", "--force", help='Force install. Set this if virtualbox is not detected correctly.', action="store_true")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

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

if vmstatus != "vbox" and args.force is False:
    sys.exit("\nERROR: Machine is not running in a VirtualBox guest. Exiting.")

if args.noprompt is False:
    input("Press Enter to continue.")


### Install Virtualbox Guest Additions ###
# Install distro pre-requisites
if distro == "Ubuntu":

elif distro == "Fedora":


# Download and Extract Guest Additions
guestisofolder = "/var/tmp"
guestisodl = CFunc.downloadfile(vboxguesturl, guestisofolder)
