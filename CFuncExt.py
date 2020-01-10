#!/usr/bin/env python3
"""
General Python Extended Functions
Includes distribution specific and more complex common functions.
"""

# Python includes.
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

# Folder of this script
SCRIPTDIR = sys.path[0]


### Functions ###
def numix_icons(iconfolder=os.path.join(os.sep, "usr", "local", "share", "icons")):
    """
    Install Numix Circle icons using git.
    """
    # Icons
    os.makedirs(iconfolder, exist_ok=True)
    # Numix Icon Theme
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix-Light"), ignore_errors=True)
    CFunc.gitclone("https://github.com/numixproject/numix-icon-theme.git", os.path.join(iconfolder, "numix-icon-theme"))
    shutil.move(os.path.join(iconfolder, "numix-icon-theme", "Numix"), iconfolder)
    shutil.move(os.path.join(iconfolder, "numix-icon-theme", "Numix-Light"), iconfolder)
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme-circle"), ignore_errors=True)
    subprocess.run("gtk-update-icon-cache {0}".format(os.path.join(iconfolder, "Numix")), shell=True)
    # Numix Circle Icons
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme-circle"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix-Circle"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix-Circle-Light"), ignore_errors=True)
    CFunc.gitclone("https://github.com/numixproject/numix-icon-theme-circle.git", os.path.join(iconfolder, "numix-icon-theme-circle"))
    shutil.move(os.path.join(iconfolder, "numix-icon-theme-circle", "Numix-Circle"), iconfolder)
    shutil.move(os.path.join(iconfolder, "numix-icon-theme-circle", "Numix-Circle-Light"), iconfolder)
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme-circle"), ignore_errors=True)
    subprocess.run("gtk-update-icon-cache {0}".format(os.path.join(iconfolder, "Numix-Circle")), shell=True)
    subprocess.run("gtk-update-icon-cache {0}".format(os.path.join(iconfolder, "Numix-Circle-Light")), shell=True)
    return


if __name__ == '__main__':
    print("Warning, {0} is meant to be imported by a python script.".format(__file__))
