#!/usr/bin/env python3
"""Install extra Gnome Extensions"""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Gnome Extensions.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")

# Save arguments.
args = parser.parse_args()

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


# Install packages
if shutil.("zypper") is True:
    CFunc.zpinstall("git gnome-common intltool glib2-devel zip unzip gcc make")
else if shutil.which("dnf") is True:
    CFunc.dnfinstall("meson gnome-common intltool glib2-devel gettext zip unzip")
else if shutil.which("apt-get") is True:
    CFunc.aptinstall("git meson build-essential zip gnome-common gettext libglib2.0-dev")
