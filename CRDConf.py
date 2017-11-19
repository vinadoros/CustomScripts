#!/usr/bin/env python3
"""Install Remote Desktop."""

# Python includes.
import argparse
import os
import platform
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Create synergy-core configuration.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-s", "--vncsd", help='Install vnc as a systemd service.', action="store_true")
parser.add_argument("-v", "--x0vnc", help="Install vnc for the user's display.", action="store_true")
parser.add_argument("-x", "--x2go", help="Install x2go.", action="store_true")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)
# Print out configuration information
print("VNC systemd service config flag is", args.vncsd)
print("x0vnc config flag is", args.x0vnc)
print("x2go config flag is", args.x2go)


if args.noprompt is False:
    input("Press Enter to continue.")


# Install xfce for vncsd and x2go.
if args.vncsd is True or args.x2go is True:
    print("Installing xfce.")
    if shutil.which("zypper"):
        print("Installing opensuse requirements.")
        # TODO: Fill opensuse requirements.
        # CFunc.zpinstall("")
    elif shutil.which("dnf"):
        CFunc.dnfinstall("openbox xfce4-panel")
    elif shutil.which("apt-get"):
        CFunc.aptinstall("openbox xfce4-panel")

# Install vnc for vncsd and x0vnc.
if args.vncsd is True or args.x0vnc is True:
    print("Installing vnc.")
    if shutil.which("zypper"):
        CFunc.zpinstall("tigervnc autocutsel")
    elif shutil.which("dnf"):
        CFunc.dnfinstall("tigervnc tigervnc-server")
    elif shutil.which("apt-get"):
        CFunc.aptinstall("tigervnc-standalone-server vnc4server")

# Config for vncsd


# Config for x0vnc


# Config for x2go
