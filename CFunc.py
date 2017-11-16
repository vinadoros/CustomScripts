#!/usr/bin/env python3
"""Install Ubuntu Software"""

# Python includes.
import grp
import os
import platform
import pwd
import subprocess
import sys
import urllib.request

# Folder of this script
SCRIPTDIR = sys.path[0]


### Functions ###
def getnormaluser():
    """Get non-root user information."""
    if os.getenv("SUDO_USER") not in ["root", None]:
        usernamevar = os.getenv("SUDO_USER")
    elif os.getenv("USER") not in ["root", None]:
        usernamevar = os.getenv("USER")
    else:
        # https://docs.python.org/3/library/pwd.html
        usernamevar = pwd.getpwuid(1000)[0]
    # https://docs.python.org/3/library/grp.html
    usergroup = grp.getgrgid(pwd.getpwnam(usernamevar)[3])[0]
    userhome = os.path.expanduser("~{0}".format(usernamevar))
    return usernamevar, usergroup, userhome
def machinearch():
    """Get the machine arch."""
    return platform.machine()
def subpout(cmd):
    """Get output from subprocess"""
    output = subprocess.run("{0}".format(cmd), shell=True, stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return output
def dlProgress(count, blockSize, totalSize):
    """Get the progress of a download"""
    percent = int(count*blockSize*100/totalSize)
    sys.stdout.write("\r" + "Progress...%d%%" % percent)
    # If the progress is 100, print a newline.
    if percent == 100:
        sys.stdout.write("\n")
    sys.stdout.flush()
def downloadfile(url, localpath):
    """Retrieve a file and return its fullpath and filename"""
    # Get filename for extensions
    fileinfo = urllib.parse.urlparse(url)
    filename = urllib.parse.unquote(os.path.basename(fileinfo.path))
    fullpath = localpath + "/" + filename
    # Download the file if it doesn't exist.
    if os.path.isfile(fullpath) is False:
        # Download the file.
        print("Downloading {0} from {1}.".format(filename, url))
        urllib.request.urlretrieve(url, fullpath, reporthook=dlProgress)
        if not os.path.isfile(fullpath):
            sys.exit("File {0} not downloaded. Exiting.".format(filename))
    else:
        print("File {0} already exists. Skipping download.".format(fullpath))
    return (fullpath, filename)


if __name__ == '__main__':
    print("Warning, {0} is meant to be imported by a python script.".format(__file__))
