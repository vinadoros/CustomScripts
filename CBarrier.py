#!/usr/bin/env python3
"""Compile and install barrier"""

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
parser = argparse.ArgumentParser(description='Compile and install barrier.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")

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

### Functions ###
def deps_common():
    """Install dependancies common to both synergy and barrier"""
    if shutil.which("dnf"):
        print("Installing Fedora common requirements.")
        CFunc.dnfinstall("cmake make gcc-c++ libX11-devel libXtst-devel libXext-devel libXinerama-devel libcurl-devel avahi-compat-libdns_sd-devel openssl-devel rpm-build rpmlint")
    elif shutil.which("apt-get"):
        print("Installing Ubuntu common requirements.")
        CFunc.aptinstall("cmake make g++ xorg-dev libcurl4-openssl-dev libavahi-compat-libdnssd-dev libssl-dev libx11-dev")
def deps_barrier():
    """Install dependancies specific to barrier"""
    if shutil.which("dnf"):
        print("Installing Fedora barrier requirements.")
        CFunc.dnfinstall("qt5-devel")
    elif shutil.which("apt-get"):
        print("Installing Ubuntu barrier requirements.")
        CFunc.aptinstall("qtdeclarative5-dev")


if args.noprompt is False:
    input("Press Enter to continue.")


# Global Variables
RepoClonePathRoot = os.path.join("/", "var", "tmp")
RepoClonePath = os.path.join(RepoClonePathRoot, "barrier")

# Install the dependancies
deps_common()
deps_barrier()
# Clone the repo
CFunc.gitclone("https://github.com/debauchee/barrier", RepoClonePath)
os.chdir(RepoClonePath)
# subprocess.run("git checkout -f 5e1982042511cf03bd780fb5f2d96c4657c22e50", shell=True)
# Start the build.
subprocess.run(os.path.join(RepoClonePath, "clean_build.sh"), shell=True)
# Ensure user owns the folder before installation.
subprocess.run("chown {0}:{1} -R {2}".format(USERNAMEVAR, USERGROUP, RepoClonePath), shell=True)
# Copy built files.
os.chdir(os.path.join(RepoClonePath, "build"))
subprocess.run("make install", shell=True)

# Autostart barrier for the user.
barrierdesktop_file = os.path.join("/", "usr", "local", "share", "applications", "barrier.desktop")
shutil.copy2(barrierdesktop_file, os.path.join(USERHOME, ".config", "autostart"))
# Create autohide config for user if it does not already exist.
barrier_userconfig = os.path.join(USERHOME, ".config", "Debauchee", "Barrier.conf")
if not os.path.isfile(barrier_userconfig):
    os.makedirs(os.path.dirname(barrier_userconfig), exist_ok=True)
    with open(barrier_userconfig, 'w') as file:
        file.write("""[General]
autoHide=true
minimizeToTray=true""")
        subprocess.run("chown -R {0}:{1} {2}/.config".format(USERNAMEVAR, USERGROUP, USERHOME), shell=True)
# Remove source folder.
os.chdir("/")
if os.path.isdir(RepoClonePath):
    shutil.rmtree(RepoClonePath)
