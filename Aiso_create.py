#!/usr/bin/env python3
"""Create an live-cd using a virtual environment."""

# Python includes.
import argparse
import os
import signal
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]


######### Begin Functions #########
def docker_destroy(name):
    """Destroy the named docker container"""
    subprocess.run("docker stop {0}".format(name), shell=True)
    subprocess.run("docker rm {0}".format(name), shell=True)
    return


def docker_setup(image, name, options):
    """Setup the named docker container"""
    docker_destroy(name)
    subprocess.run("docker run -dt --privileged --name {0} {1} {2} bash".format(name, options, image), shell=True)
    return


def docker_runcmd(name, cmd):
    """Run a command in the named docker container"""
    subprocess.run("docker exec -it --privileged {0} {1}".format(name, cmd), shell=True)
    return


def signal_handler(sig, frame):
    """Handle a SIGINT signal."""
    docker_destroy(docker_name)
    print('Exiting due to SIGINT.')
    sys.exit(1)
######### End Functions #########


# Attach signal handler.
signal.signal(signal.SIGINT, signal_handler)

# Get arguments
parser = argparse.ArgumentParser(description='Build LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolder", help='Location of Working Folder')
parser.add_argument("-t", "--type", help='1=Ubuntu, 2=Fedora, 3=Debian', type=int, default=0)
parser.add_argument("-r", "--release", help='Release of LiveCD')

# Save arguments.
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Process variables
buildfolder = os.path.abspath(args.workfolder)
print("Using work folder {0}.".format(buildfolder))
print("Type: {0}".format(args.type))
print("Release: {0}".format(args.release))

if args.noprompt is False:
    input("Press Enter to continue.")

if args.type == 1:
    print("Ubuntu")
    os.makedirs(buildfolder, mode=0o777, exist_ok=True)
    os.chmod(buildfolder, 0o777)
    docker_name = "ubuiso"
    docker_image = "ubuntu:bionic"
    docker_options = '-v /opt/CustomScripts:/opt/CustomScripts -v "{0}":"{0}"'.format(buildfolder)
    docker_destroy(docker_name)
    docker_setup(docker_image, docker_name, docker_options)
    docker_runcmd(docker_name, "apt-get update")
    docker_runcmd(docker_name, "apt-get install -y python3")
    docker_isocmd = '/opt/CustomScripts/Aubuiso.py -n -w "{0}"'.format(buildfolder)
    if args.release:
        docker_isocmd += " -r {0}".format(args.release)
    try:
        docker_runcmd(docker_name, docker_isocmd)
    finally:
        docker_destroy(docker_name)
if args.type == 2:
    print("Fedora")
    os.makedirs(buildfolder, mode=0o777, exist_ok=True)
    os.chmod(buildfolder, 0o777)
    docker_name = "fediso"
    docker_image = "fedora:latest"
    docker_options = '-v /opt/CustomScripts:/opt/CustomScripts -v "{0}":"{0}"'.format(buildfolder)
    docker_destroy(docker_name)
    docker_setup(docker_image, docker_name, docker_options)
    docker_runcmd(docker_name, "dnf install -y nano livecd-tools spin-kickstarts pykickstart anaconda util-linux")
    docker_isocmd = '/opt/CustomScripts/Afediso.py -n -w "{0}" -o "{0}"'.format(buildfolder)
    if isinstance(args.release, int):
        docker_isocmd += ' -r {0}'.format(args.release)
    try:
        docker_runcmd(docker_name, docker_isocmd)
    finally:
        docker_destroy(docker_name)
if args.type == 3:
    print("Debian")
    os.makedirs(buildfolder, mode=0o777, exist_ok=True)
    os.chmod(buildfolder, 0o777)
    docker_name = "debiso"
    docker_image = "debian:testing"
    docker_options = '-v /opt/CustomScripts:/opt/CustomScripts -v "{0}":"{0}"'.format(buildfolder)
    docker_destroy(docker_name)
    docker_setup(docker_image, docker_name, docker_options)
    docker_runcmd(docker_name, "apt-get update")
    docker_runcmd(docker_name, "apt-get install -y nano git build-essential debhelper devscripts live-build syslinux isolinux rsync po4a python3")
    docker_isocmd = '/opt/CustomScripts/Adebiso.py -n -w "{0}" -o "{0}"'.format(buildfolder)
    try:
        docker_runcmd(docker_name, docker_isocmd)
    finally:
        docker_destroy(docker_name)
