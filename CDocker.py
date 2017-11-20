#!/usr/bin/env python3
"""Install and Setup Docker"""

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
parser = argparse.ArgumentParser(description='Install Docker.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-r", "--release", help='Force operating system release. Set this if a particular release should be forced.')

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


# Detect OS information
distro = CFunc.subpout("lsb_release -si")
if args.release is None:
    release = CFunc.subpout("lsb_release -sc")
else:
    release = args.release
print("Distro is {0}.".format(distro))
print("Release is {0}.".format(release))

if args.noprompt is False:
    input("Press Enter to continue.")

### Install Docker ###
if distro == "Ubuntu":
    # Import keyfile
    key = CFunc.downloadfile("https://download.docker.com/linux/ubuntu/gpg", "/tmp")
    subprocess.run("apt-key add {0}".format(key[0]), shell=True, check=True)
    os.remove(key[0])
    # Write sources list
    with open('/etc/apt/sources.list.d/docker.list', 'w') as stapt_writefile:
        stapt_writefile.write("deb [arch=amd64] https://download.docker.com/linux/ubuntu {0} stable edge".format(release))
    # Install.
    subprocess.run('apt-get update; apt-get install -y docker-ce', shell=True)
    subprocess.run("usermod -aG docker {0}".format(USERNAMEVAR), shell=True)
elif distro == "Fedora":
    # Install repo file.
    subprocess.run("""
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
dnf config-manager --set-enabled docker-ce-edge
""", shell=True, check=True)
    # Modify repo file
    if release.isdigit() is True:
        subprocess.run("sed -i 's/$releasever/{0}/g' /etc/yum.repos.d/docker-ce.repo".format(release), shell=True)
    # Install
    subprocess.run("dnf install -y docker-ce", shell=True)
    subprocess.run("usermod -aG docker {0}".format(USERNAMEVAR), shell=True)

### Docker Configuration ###
if shutil.which("docker"):
    # Check for portainer.
    if "portainer" not in CFunc.subpout("docker ps -a"):
        # Install portainer.
        subprocess.run("docker run -d --name portainer --restart=always -p 61234:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer", shell=True)
    else:
        print("\nPortainer detected. Not re-installing.")
else:
    print("\ndocker command not found, not proceeding.")