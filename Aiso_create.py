#!/usr/bin/env python3
"""Create an live-cd using a virtual environment."""

# Python includes.
import argparse
import os
import shutil
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
    subprocess.run("docker stop {0}".format(name), shell=True, check=False)
    subprocess.run("docker rm {0}".format(name), shell=True, check=False)
    return


def docker_setup(image, name, options):
    """Setup the named docker container"""
    docker_destroy(name)
    subprocess.run("docker pull {0}".format(image), shell=True, check=True)
    subprocess.run("docker run -dt --privileged --name {0} {1} {2} bash".format(name, options, image), shell=True, check=True)
    return


def docker_runcmd(name, cmd):
    """Run a command in the named docker container"""
    subprocess.run("docker exec -it --privileged {0} {1}".format(name, cmd), shell=True, check=False)
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
parser.add_argument("-c", "--clean", help='Remove ISO folder before starting.', action="store_true")
parser.add_argument("-d", "--debug", help='Spawn a bash prompt before destroying the vagrant machine.', action="store_true")
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-r", "--release", help='Release of LiveCD')
parser.add_argument("-t", "--type", help='1=Ubuntu, 2=Fedora', type=int, default=0)
parser.add_argument("-w", "--workfolder", help='Location of Working Folder')
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Process variables
workfolder = os.path.abspath(args.workfolder)
print("Using work folder {0}.".format(workfolder))
print("Type: {0}".format(args.type))
print("Release: {0}".format(args.release))
print("Clean: {0}".format(args.clean))

if args.noprompt is False:
    input("Press Enter to continue.")

# Clean folder.
if os.path.isdir(workfolder) and args.clean:
    shutil.rmtree(workfolder)
# Create folder.
if not os.path.isdir(workfolder):
    os.makedirs(workfolder, mode=0o777, exist_ok=True)
os.chmod(workfolder, 0o777)

if args.type == 1:
    print("Ubuntu")
    docker_name = "ubuiso"
    docker_image = "ubuntu:rolling"
    docker_options = '-v /opt/CustomScripts:/opt/CustomScripts -e DEBIAN_FRONTEND=noninteractive -v "{0}":"{0}"'.format(workfolder)
    docker_destroy(docker_name)
    docker_setup(docker_image, docker_name, docker_options)
    docker_runcmd(docker_name, "apt-get update")
    docker_runcmd(docker_name, "apt-get install -y python3")
    docker_isocmd = '/opt/CustomScripts/Aubuiso.py -n -w "{0}"'.format(workfolder)
    if args.release:
        docker_isocmd += " -r {0}".format(args.release)
if args.type == 2:
    print("Fedora")
    docker_name = "fediso"
    docker_image = "fedora:latest"
    docker_options = '-v /opt/CustomScripts:/opt/CustomScripts -v "{0}":"{0}"'.format(workfolder)
    docker_destroy(docker_name)
    docker_setup(docker_image, docker_name, docker_options)
    docker_runcmd(docker_name, "dnf install -y nano livecd-tools spin-kickstarts pykickstart anaconda util-linux")
    docker_isocmd = '/opt/CustomScripts/Afediso.py -n -w "{0}" -o "{0}"'.format(workfolder)
    if isinstance(args.release, int):
        docker_isocmd += ' -r {0}'.format(args.release)

# Run docker
try:
    docker_runcmd(docker_name, docker_isocmd)
finally:
    if args.debug:
        docker_runcmd(docker_name, "bash")
    docker_destroy(docker_name)
