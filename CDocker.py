#!/usr/bin/env python3
"""Install and Setup Docker"""

# Python includes.
import argparse
import json
import os
import shutil
import subprocess
import sys
import urllib.request
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Docker.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-r", "--release", help='Force operating system release. Set this if a particular release should be forced.')
parser.add_argument("-f", "--force", help='Force re-installation of portainer.', action="store_true")

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
distro, release = CFunc.detectdistro()
if args.release is not None:
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

### Docker Compose Install ###
# Get the docker-compose version information from GitHub.
if shutil.which("docker") and (not shutil.which("docker-compose") or args.force is True):
    dc_releasejson_link = "https://api.github.com/repos/docker/compose/releases"
    # Get the kernel name and machine arch.
    dc_kernelname = CFunc.subpout("uname -s")
    dc_machinearch = CFunc.machinearch()
    # Get the json data from GitHub.
    with urllib.request.urlopen(dc_releasejson_link) as dc_releasejson_handle:
        dc_releasejson_data = json.load(dc_releasejson_handle)
    for release in dc_releasejson_data:
        # Search for the latest non-rc release.
        if "-rc" not in release["name"]:
            # Stop after the first (latest) release is found.
            dc_latestrelease = (release["name"])
            break
    # Download docker-compose
    dc_dl = CFunc.downloadfile("https://github.com/docker/compose/releases/download/{0}/docker-compose-{1}-{2}".format(dc_latestrelease, dc_kernelname, dc_machinearch), "/usr/local/bin", "docker-compose", True)
    # Make docker-compose executable
    os.chmod(dc_dl[0], 0o777)


### Docker Configuration ###
if shutil.which("docker"):
    # Command to install portainer.
    portainer_name = "portainer"
    portainer_cmd = "docker pull portainer/portainer; docker run -d --name {0} --restart=always -p 61234:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer".format(portainer_name)
    # Check for portainer.
    portainer_check = CFunc.subpout("docker ps -a")
    # Remove portainer if force was set and portainer was detected.
    if "portainer" in portainer_check and args.force is True:
        subprocess.run("docker stop {0}; docker rm {0}".format(portainer_name), shell=True)
    # Install portainer if not found.
    if "portainer" not in portainer_check or args.force is True:
        print("Installing portainer.")
        subprocess.run(portainer_cmd, shell=True)
    else:
        print("\nPortainer detected. Not re-installing.")
else:
    print("\ndocker command not found, not proceeding.")
