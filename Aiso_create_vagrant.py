#!/usr/bin/env python3
"""Create an live-cd using vagrant."""

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

# Get arguments
parser = argparse.ArgumentParser(description='Build LiveCD.')
parser.add_argument("-d", "--debug", help='Spawn a bash prompt before destroying the vagrant machine.', action="store_true")
parser.add_argument("-n", "--noprompt", help='Do not prompt.', action="store_true")
parser.add_argument("-r", "--release", help='Release of LiveCD')
parser.add_argument("-t", "--type", help='1=Fedora, 2=Debian', type=int, default=0)
parser.add_argument("-w", "--workfolder", help='Location of Working Folder')
args = parser.parse_args()

# Variables
workfolder = os.path.abspath(args.workfolder)
vagrantfile_folder = os.path.join(workfolder, "vg")

######### Begin Functions #########
def vagrant_destroy():
    """Destroy the vagrant machine"""
    if os.path.isdir(vagrantfile_folder):
        os.chdir(vagrantfile_folder)
        subprocess.run("vagrant halt; vagrant destroy -f", shell=True, check=False)
    return


def vagrant_setup(vagrantfile_text):
    """Bring up the vagrant machine"""
    if os.path.isdir(vagrantfile_folder):
        vagrant_destroy()
    os.makedirs(workfolder, exist_ok=True)
    os.makedirs(vagrantfile_folder, exist_ok=True)
    os.chdir(vagrantfile_folder)
    vagrantfile_path = os.path.join(vagrantfile_folder, "Vagrantfile")
    with open(vagrantfile_path, 'w') as f:
        f.write(vagrantfile_text)
    subprocess.run("vagrant up --provider=libvirt", shell=True, check=True)
    return


def vagrant_runcmd(cmd, error_on_fail: bool = True):
    """Run a command using vagrant ssh"""
    os.chdir(vagrantfile_folder)
    subprocess.run("vagrant ssh -c '{0}'".format(cmd), shell=True, check=error_on_fail)
    return


def signal_handler(sig, frame):
    """Handle a SIGINT signal."""
    vagrant_destroy()
    print('Exiting due to SIGINT.')
    sys.exit(1)
######### End Functions #########


# Attach signal handler.
signal.signal(signal.SIGINT, signal_handler)


# Exit if root.
CFunc.is_root(False)

# Process variables
print("Using work folder {0}.".format(workfolder))
print("Type: {0}".format(args.type))
print("Release: {0}".format(args.release))

if not shutil.which("vagrant"):
    print("ERROR: vagrant command not found. Exiting.")
    sys.exit(1)

if args.noprompt is False:
    input("Press Enter to continue.")

if args.type == 1:
    print("Fedora")
    if isinstance(args.release, int):
        release = args.release
    else:
        release = 33

    # Vagrantfile for fedora iso
    vagrantfile = """Vagrant.configure("2") do |config|
  config.vm.box = "fedora/{release}-cloud-base"
  config.vm.synced_folder "{workfolder}", "{workfolder}", type: "sshfs"
  config.vm.synced_folder "{scriptdir}", "/opt/CustomScripts", type: "sshfs"
  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = 4
    libvirt.cputopology :sockets => '1', :cores => '4', :threads => '1'
    libvirt.memory = 4096
  end
end
""".format(workfolder=workfolder, release=release, scriptdir=SCRIPTDIR)
    try:
        vagrant_setup(vagrantfile)
        vagrant_runcmd("sudo dnf install -y nano livecd-tools spin-kickstarts pykickstart anaconda util-linux")
        vagrant_runcmd('sudo /opt/CustomScripts/Afediso.py -n -w "/root" -o "{workfolder}"'.format(workfolder=workfolder))
    finally:
        if args.debug:
            vagrant_runcmd('bash')
        vagrant_destroy()
if args.type == 2:
    print("Ubuntu")
    if isinstance(args.release, int):
        release = args.release
    else:
        release = "2004"

    # Vagrantfile for ubuntu iso
    vagrantfile = """Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"
  config.vm.synced_folder "{workfolder}", "{workfolder}", type: "sshfs"
  config.vm.synced_folder "{scriptdir}", "/opt/CustomScripts", type: "sshfs"
  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = 4
    libvirt.cputopology :sockets => '1', :cores => '4', :threads => '1'
    libvirt.memory = 4096
  end
end
""".format(workfolder=workfolder, scriptdir=SCRIPTDIR)
    try:
        vagrant_setup(vagrantfile)
        vagrant_runcmd('apt-get update')
        vagrant_runcmd('apt-get install -y python3')
        isocmd = 'sudo /opt/CustomScripts/Aubuiso.py -n -w "{0}"'.format(workfolder)
        if args.release:
            isocmd += " -r {0}".format(args.release)
        vagrant_runcmd(isocmd)
    finally:
        if args.debug:
            vagrant_runcmd('bash')
        vagrant_destroy()
