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
# Temp folder
tempfolder = "/var/tmp/tempfolder_gse"

# Get arguments
parser = argparse.ArgumentParser(description='Install Gnome Extensions.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-d", "--dashtodock", help='Dash to Dock.', action="store_true")
parser.add_argument("-m", "--mediaplayer", help='Media Player Extension.', action="store_true")
parser.add_argument("-v", "--volumemixer", help='Volume Mixer.', action="store_true")
parser.add_argument("-t", "--topicons", help='Top Icons Plus.', action="store_true")
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)

# Install packages
if shutil.which("zypper"):
    CFunc.zpinstall("meson git gnome-common intltool glib2-devel zip unzip gcc make")
elif shutil.which("dnf"):
    CFunc.dnfinstall("meson git gnome-common intltool glib2-devel gettext zip unzip")
elif shutil.which("apt-get"):
    CFunc.aptinstall("git meson build-essential zip gnome-common gettext libglib2.0-dev")

### Functions ###
def gitclone(url, path):
    """Clone a git repository to a given local path."""
    subprocess.run("git clone {0} {1}".format(url, path), shell=True)
    subprocess.run("chmod a+rw -R {0}".format(path), shell=True)
def cleantempfolder():
    """Remove the temporary folder if it exists."""
    if os.path.isdir(tempfolder):
        shutil.rmtree(tempfolder)
def dashtodock():
    """Dash to Dock"""
    print("\nInstalling Dash to Dock.")
    gitclone("https://github.com/micheleg/dash-to-dock.git", tempfolder)
    subprocess.run("cd {0}; su {1} -c 'make; make install'".format(tempfolder, USERNAMEVAR), shell=True)
    cleantempfolder()
def mediaplayer():
    """Media Player Extension"""
    print("\nInstalling Media Player Extension.")
    gitclone("https://github.com/JasonLG1979/gnome-shell-extensions-mediaplayer.git", tempfolder)
    subprocess.run("cd {0}; su {1} -c './build'".format(tempfolder, USERNAMEVAR), shell=True)
    cleantempfolder()
def volumemixer():
    """Volume Mixer"""
    print("\nInstalling Volume Mixer.")
    gitclone("https://github.com/aleho/gnome-shell-volume-mixer.git", tempfolder)
    volumemixer_path = os.path.abspath("{0}/.local/share/gnome-shell/extensions/shell-volume-mixer@derhofbauer.at/".format(USERHOME))
    os.makedirs(volumemixer_path, exist_ok=True)
    subprocess.run("cd {0}; make; 7z x ./shell-volume-mixer*.zip -aoa -o{1}".format(tempfolder, volumemixer_path), shell=True)
    subprocess.run("chown {0}:{1} -R {2}/.local/".format(USERNAMEVAR, USERGROUP, USERHOME), shell=True)
    cleantempfolder()
def topiconsplus():
    """Top Icons Plus"""
    print("\nInstalling Top Icons Plus.")
    gitclone("https://github.com/phocean/TopIcons-plus", tempfolder)
    subprocess.run("cd {0}; su {1} -c 'make'".format(tempfolder, USERNAMEVAR), shell=True)
    cleantempfolder()


### Begin Clone ###
cleantempfolder()
try:
    if args.dashtodock is True:
        dashtodock()
    if args.mediaplayer is True:
        mediaplayer()
    if args.volumemixer is True:
        volumemixer()
    if args.topicons is True:
        topiconsplus()
finally:
    cleantempfolder()
