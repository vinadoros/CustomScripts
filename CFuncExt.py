#!/usr/bin/env python3
"""
General Python Extended Functions
Includes distribution specific and more complex common functions.
"""

# Python includes.
import os
import re
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
def SudoersEnvSettings(sudoers_file=os.path.join(os.sep, "etc", "sudoers")):
    """
    Change sudoers settings.
    """
    if os.path.isfile(sudoers_file):
        CFunc.BackupSudoersFile(sudoers_file)
        with open(sudoers_file, 'r') as sources:
            lines = sources.readlines()
        with open(sudoers_file, mode='w') as f:
            for line in lines:
                # Debian/Ubuntu use tabs, Fedora uses spaces. Check for both.
                line = re.sub(r'^(Defaults(\t|\s{4})mail_badpass)', r'# \1', line)
                # Set to not reset environment when sudoing.
                line = re.sub(r'^(Defaults(\t|\s{4})env_reset)$', r'Defaults\t!env_reset', line)
                line = re.sub(r'^(Defaults(\t|\s{4})secure_path)', r'# \1', line)
                f.write(line)
        CFunc.CheckRestoreSudoersFile(sudoers_file)
    else:
        print("ERROR: {0} does not exists, not modifying sudoers.".format(sudoers_file))


if __name__ == '__main__':
    print("Warning, {0} is meant to be imported by a python script.".format(__file__))
