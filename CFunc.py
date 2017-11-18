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
    # If the progress is 100 (or more), print a newline.
    if percent >= 100:
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
### Systemd Functions ###
def systemd_createsystemunit(sysunitname, sysunittext, sysenable=False):
    """Create a systemd system unit."""
    SystemdSystemUnitPath = "/etc/systemd/system/"
    # Make sure systemd system unit path exists.
    if not os.path.isdir(SystemdSystemUnitPath):
        print("\nError: Systemd system unit path {0} does not exist.\n".format(SystemdSystemUnitPath))
        return 1
    fullunitpath = SystemdSystemUnitPath + "/" + sysunitname
    # Write the unit file.
    print("Creating {0}.".format(fullunitpath))
    with open(fullunitpath, 'w') as fullunitpath_write:
        fullunitpath_write.write(sysunittext)
    # Enable the unit if specified.
    if sysenable is True:
        subprocess.run("systemctl daemon-reload", shell=True)
        subprocess.run("systemctl enable {0}".format(sysunitname), shell=True)
    return 0
def systemd_createuserunit(userunitname, userunittext):
    """Create a systemd user unit."""
    # Get the normal user.
    USERNAMEVAR, USERGROUP, USERHOME = getnormaluser()
    # Set systemd user folder paths
    SystemdUser_UnitPath = USERHOME + "/.config/systemd/user"
    SystemdUser_DefaultTargetPath = SystemdUser_UnitPath + "/default.target.wants"
    # Create the foldrs if they don't exist
    os.makedirs(SystemdUser_UnitPath, exist_ok=True)
    os.makedirs(SystemdUser_DefaultTargetPath, exist_ok=True)
    # Create the default target.
    SystemdUser_DefaultTargetUnitFile = SystemdUser_DefaultTargetPath + "/default.target"
    print("Creating {0}".format(SystemdUser_DefaultTargetUnitFile))
    with open(SystemdUser_DefaultTargetUnitFile, 'w') as tgtunitfile_write:
        tgtunitfile_write.write("""[Unit]
Description=Default target
Requires=dbus.socket
AllowIsolate=true""")
    # Create the user unit file.
    SystemdUser_UnitFilePath = SystemdUser_UnitPath + "/" + userunitname
    print("Creating {0}.".format(SystemdUser_UnitFilePath))
    with open(SystemdUser_UnitFilePath, 'w') as userunitfile_write:
        userunitfile_write.write(userunittext)
    # Symlink the unit file in the default target.
    SystemdUser_DefaultTargetUserUnitSymlinkPath = SystemdUser_DefaultTargetPath + "/" + userunitname
    # Remove any existing item.
    if os.path.exists(SystemdUser_DefaultTargetUserUnitSymlinkPath):
        os.remove(SystemdUser_DefaultTargetUserUnitSymlinkPath)
    # Create the symlink.
    os.symlink(SystemdUser_UnitFilePath, SystemdUser_DefaultTargetUserUnitSymlinkPath)
    # Set proper ownership if running as root.
    if os.geteuid() is 0:
        subprocess.run("chown {0}:{1} -R {2}/.config".format(USERNAMEVAR, USERGROUP, USERHOME), shell=True)
    else:
        # Run daemon-reload if not running as root.
        subprocess.run("systemctl --user daemon-reload", shell=True)
    return 0
### Package Manager Specific Functions ###
# Apt
def aptupdate():
    """Update apt sources"""
    subprocess.run("apt-get update", shell=True)
def aptdistupg():
    """Upgrade/Dist-Upgrade system using apt"""
    aptupdate()
    print("\nPerforming (dist)upgrade.")
    subprocess.run("apt-get upgrade -y", shell=True)
    subprocess.run("apt-get dist-upgrade -y", shell=True)
def aptinstall(aptapps):
    """Install application(s) using apt"""
    print("\nInstalling {0} using apt.".format(aptapps))
    subprocess.run("apt-get install -y {0}".format(aptapps), shell=True)
# DNF
def dnfupdate():
    """Update system"""
    print("\nPerforming system update.")
    subprocess.run("dnf update -y", shell=True)
def dnfinstall(dnfapps):
    """Install application(s)"""
    print("\nInstalling {0} using dnf.".format(dnfapps))
    subprocess.run("dnf install -y {0}".format(dnfapps), shell=True)
# Zypper
def zpinstall(zpapps):
    """Install application(s)"""
    print("\nInstalling {0} using zypper.".format(zpapps))
    subprocess.run("zypper in -yl {0}".format(zpapps), shell=True)


if __name__ == '__main__':
    print("Warning, {0} is meant to be imported by a python script.".format(__file__))
