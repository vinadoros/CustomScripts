#!/usr/bin/env python3
"""Install Virtualbox for host machine"""

# Python includes.
import argparse
import grp
import os
import platform
import pwd
import shutil
import subprocess
import sys
import urllib.request

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Virtualbox Host Software.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-r", "--release", help='Force operating system release. Set this if a particular release should be forced.')

# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
if os.getenv("SUDO_USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("SUDO_USER")
elif os.getenv("USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR = pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP = grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
USERHOME = os.path.expanduser("~{0}".format(USERNAMEVAR))
MACHINEARCH = platform.machine()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


### Functions ###
def subpout(cmd):
    """Get output from subprocess"""
    output = subprocess.run("{0}".format(cmd), shell=True, stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return output
def downloadfile(url, localpath):
    """Retrieve a file and return its fullpath and filename"""
    # Get filename for extensions
    fileinfo = urllib.parse.urlparse(url)
    filename = urllib.parse.unquote(os.path.basename(fileinfo.path))
    fullpath = localpath + "/" + filename
    # Download the file.
    print("Downloading {0}.".format(filename))
    urllib.request.urlretrieve(url, fullpath)
    if not os.path.isfile(fullpath):
        sys.exit("File {0} not downloaded. Exiting.".format(filename))
    return (fullpath, filename)


# Detect major virtualbox version
vboxver_url = "http://download.virtualbox.org/virtualbox/LATEST.TXT"
vboxver_data = urllib.request.urlopen(vboxver_url)
vboxfullver = vboxver_data.read().decode().strip().split(".")
# Save the version if both split items are digits.
if vboxfullver[0].isdigit() and vboxfullver[1].isdigit():
    VBOXMAJORVERSION = vboxfullver[0] + "." + vboxfullver[1]
else:
    # Default to a fixed version if detection failed.
    print("\nAutodetect of Virtualbox version failed. Defaulting to fixed value.")
    VBOXMAJORVERSION = "5.2"
print("Virtualbox major version is {0}.".format(VBOXMAJORVERSION))

# Detect OS information
distro = subpout("lsb_release -si")
if args.release is None:
    release = subpout("lsb_release -sc")
else:
    release = args.release
print("Distro is {0}.".format(distro))
print("Release is {0}.".format(release))

if args.noprompt is False:
    input("Press Enter to continue.")

### Install Virtualbox ###
if distro == "Ubuntu":
    # Import keyfile
    key = downloadfile("https://www.virtualbox.org/download/oracle_vbox_2016.asc", "/tmp")
    subprocess.run("apt-key add {0}".format(key[0]), shell=True, check=True)
    os.remove(key[0])
    # Write virtualbox sources list
    with open('/etc/apt/sources.list.d/virtualbox.list', 'w') as stapt_writefile:
        stapt_writefile.write("deb http://download.virtualbox.org/virtualbox/debian {0} contrib".format(release))
    # Install virtualbox.
    subprocess.run('apt-get update; apt-get install -y virtualbox-{0}'.format(VBOXMAJORVERSION), shell=True)
elif distro == "Fedora":
    # Import keyfile
    key = downloadfile("https://www.virtualbox.org/download/oracle_vbox.asc", "/tmp")
    subprocess.run("rpm --import {0}".format(key[0]), shell=True, check=True)
    os.remove(key[0])
    # Add repo file.
    subprocess.run("""
dnf install -y dkms
dnf config-manager --add-repo "http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo"
""", shell=True)
    # Modify repo file.
    if release.isdigit() is True:
        subprocess.run("sed -i 's/$releasever/{0}/g' /etc/yum.repos.d/virtualbox.repo".format(release))
    # Install.
    subprocess.run("""
dnf install -y VirtualBox-{0}
usermod -aG vboxusers {1}
""".format(VBOXMAJORVERSION, USERNAMEVAR), shell=True, check=True)

### Install Host Extensions ###
if shutil.which("vboxmanage"):
    vboxver = subpout("vboxmanage -v")
    vboxver2 = subpout("echo {0} | cut -d 'r' -f 1".format(vboxver))
    print("Detected Virtualbox version:", vboxver2)
    # Set extensions url
    exturl = "http://download.virtualbox.org/virtualbox/{0}/Oracle_VM_VirtualBox_Extension_Pack-{0}.vbox-extpack".format(vboxver2)
    # Get the file
    extpath, extname = downloadfile(exturl, "/tmp")
    # Install the extensions
    subprocess.run("yes | VBoxManage extpack install --replace {0}".format(extpath), shell=True, check=True)
    # Remove the file
    os.remove(extpath)
else:
    print("\nvboxmanage command not found, not installing Virtualbox extensions.")
