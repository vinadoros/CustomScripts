#!/usr/bin/env python3
"""Install extra Gnome Extensions"""

# Python includes.
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]
# Temp folder
tempfolder = os.path.join("/", "var", "tmp", "tempfolder_gse")

# Get arguments
parser = argparse.ArgumentParser(description='Install Gnome Extensions.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-d", "--dashtodock", help='Dash to Dock.', action="store_true")
parser.add_argument("-v", "--volumemixer", help='Volume Mixer.', action="store_true")
parser.add_argument("-t", "--topicons", help='Top Icons Plus.', action="store_true")
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

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
    CFunc.gitclone(url, path)
    subprocess.run("chmod -R a+rw {0}".format(path), shell=True)
def cleantempfolder():
    """Remove the temporary folder if it exists."""
    if os.path.isdir(tempfolder):
        shutil.rmtree(tempfolder)
def dashtodock():
    """Dash to Dock"""
    print("\nInstalling Dash to Dock.")
    gitclone("https://github.com/micheleg/dash-to-dock.git", tempfolder)
    CFunc.run_as_user(USERNAMEVAR, "cd {0}; make; make install".format(tempfolder))
    cleantempfolder()
def volumemixer():
    """Volume Mixer"""
    print("\nInstalling Volume Mixer.")
    releasejson_link = "https://api.github.com/repos/aleho/gnome-shell-volume-mixer/releases"
    # Get the json data from GitHub.
    with urllib.request.urlopen(releasejson_link) as releasejson_handle:
        releasejson_data = json.load(releasejson_handle)
    # Get the url
    dl_link = None
    counter = 0
    # Try to loop through to get the link 100 times. Fail afterwards.
    while not dl_link:
        try:
            dl_link = releasejson_data[counter]['assets'][0]['browser_download_url']
        except Exception: 
            pass
        if counter >= 100:
            print("ERROR: Could not find dl_link for Volume extension.")
            break
        counter += 1
    # Download
    dl_path = CFunc.downloadfile(dl_link, tempfile.gettempdir(), overwrite=True)
    # Create user folder for volume mixer
    volumemixer_path = os.path.abspath("{0}/.local/share/gnome-shell/extensions/shell-volume-mixer@derhofbauer.at/".format(USERHOME))
    os.makedirs(volumemixer_path, exist_ok=True)
    # Extract volumemixer
    subprocess.run("7z x {0} -aoa -o{1}".format(dl_path[0], volumemixer_path), shell=True)
    subprocess.run("chown -R {0}:{1} {2}/.local/".format(USERNAMEVAR, USERGROUP, USERHOME), shell=True)
    os.remove(dl_path[0])
def topiconsplus():
    """Top Icons Plus"""
    print("\nInstalling Top Icons Plus.")
    gitclone("https://github.com/phocean/TopIcons-plus", tempfolder)
    CFunc.run_as_user(USERNAMEVAR, "cd {0}; make".format(tempfolder))
    cleantempfolder()


### Begin Clone ###
cleantempfolder()
try:
    if args.dashtodock is True:
        dashtodock()
    if args.volumemixer is True:
        volumemixer()
    if args.topicons is True:
        topiconsplus()
finally:
    cleantempfolder()
