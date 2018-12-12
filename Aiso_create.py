#!/usr/bin/env python3
"""Create an live-cd using a virtual environment."""

# Python includes.
import argparse
from datetime import datetime
import os
import shutil
import subprocess
import sys
import time
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]


### Functions ###
def docker_destroy(name):
    subprocess.run("docker stop {0}".format(name), shell=True)
    subprocess.run("docker rm {0}".format(name), shell=True)
    return
def docker_setup(image, name, options):
    docker_destroy(name)
    subprocess.run("docker run -dt --privileged --name {0} {1} {2} bash".format(name, options, image), shell=True)
    return
def docker_runcmd(name, cmd):
    subprocess.run("docker exec -it --privileged {0} {1}".format(name, cmd), shell=True)
    return


# Exit if not root.
CFunc.is_root(True)

# Get arguments
parser = argparse.ArgumentParser(description='Build LiveCD.')
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-w", "--workfolder", help='Location of Working Folder')
parser.add_argument("-t", "--type", help='1=Ubuntu, 2=Fedora, 3=Debian', type=int, default=0)
parser.add_argument("-r", "--release", help='Release of LiveCD')

# Save arguments.
args = parser.parse_args()

# Process variables
buildfolder = os.path.abspath(args.workfolder)
print("Using work folder {0}.".format(buildfolder))
print("Type: {0}".format(args.type))
print("Release: {0}".format(args.release))

if args.noprompt is False:
    input("Press Enter to continue.")

if args.type == 1:
    print("Ubuntu")
    docker_name = "ubuiso"
    docker_image = "ubuntu:bionic"
    docker_options = "-v /opt/CustomScripts:/opt/CustomScripts"
    docker_destroy(docker_name)
    docker_setup(docker_image, docker_name, docker_options)
    docker_runcmd(docker_name, "apt-get update")
    docker_runcmd(docker_name, "apt-get install -y python3")
    docker_isocmd = "/opt/CustomScripts/Aubuiso.py -n -w /root/temp"
    if args.release:
        docker_isocmd += " -r {0}".format(args.release)
    docker_runcmd(docker_name, docker_isocmd)

