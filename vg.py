#!/usr/bin/env python3

# Python includes.
import argparse
import os
import sys
import subprocess
import shutil
import stat

print("Running {0}".format(__file__))

# Exit if root.
if os.geteuid() is 0:
    sys.exit("\nError: Please run this script as a normal user (not root).\n")

# Ensure that certain commands exist.
cmdcheck = ["vagrant", "ssh"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

# Globals
# Folder of this script
SCRIPTDIR=sys.path[0]
# Home Folder
USERHOME=os.path.expanduser("~")
# Folder containing Vagrantfile-this
VAGRANTSCRIPTSFOLDER = USERHOME+"/VagrantScripts"

# Get arguments
parser = argparse.ArgumentParser(description='Copy and start a vagrant file.')
parser.add_argument("filename", help='File name of Vagrantfile (i.e. \"this\" for Vagrantfile-this)')
parser.add_argument("-p", "--provision", help="Provision the VM before starting", action="store_true")
parser.add_argument("-k", "--halt", help="Halt the VM", action="store_true")
parser.add_argument("-d", "--destroy", help="Halts and Destroys the VM", action="store_true")
parser.add_argument("-n", "--donotstart", help="Do not start the VM (useful if only destroying or halting)", action="store_true")

# Save arguments.
args = parser.parse_args()

# Search for vagrantfiles.
VAGRANTFILE = None
VAGRANTFULLPATH = None
VAGRANTFOLDERNAME = None
for root, dirs, files in os.walk(SCRIPTDIR):
    for filename in files:
        if filename.startswith('Vagrantfile') and filename.endswith(args.filename):
            VAGRANTFILE = filename
            VAGRANTFULLPATH = root + "/" + filename
            VAGRANTFOLDERNAME = VAGRANTFILE.replace("Vagrantfile-", "")

if VAGRANTFILE is not None:
    # Create the Vagrantscripts
    if not os.path.isdir(VAGRANTSCRIPTSFOLDER):
        print("Creating folder",VAGRANTSCRIPTSFOLDER)
        os.makedirs(VAGRANTSCRIPTSFOLDER, exist_ok=True)

    # Create the subfolder if it doesn't exist.
    VAGRANTFULLFOLDERPATH = VAGRANTSCRIPTSFOLDER+"/"+VAGRANTFOLDERNAME
    if not os.path.isdir(VAGRANTFULLFOLDERPATH):
        print("Creating folder",VAGRANTFULLFOLDERPATH)
        os.makedirs(VAGRANTFULLFOLDERPATH, exist_ok=True)

    # Copy the vagrantfile into the folder.
    print("Copying",VAGRANTFULLPATH,"to",VAGRANTFULLFOLDERPATH)
    shutil.copy2(VAGRANTFULLPATH, VAGRANTFULLFOLDERPATH+"/Vagrantfile")

    os.chdir(VAGRANTFULLFOLDERPATH)

else:
    sys.exit("\nError, vagrant file not found.")

if args.halt == True or args.destroy == True:
    print("Halting VM.")
    subprocess.run("vagrant halt", shell=True)
    if args.destroy == True:
        print("Destroying VM.")
        subprocess.run("vagrant destroy -f", shell=True)

if args.donotstart == False:
    # Bring the box up and ssh in.
    print("Running vagrant up.")
    subprocess.run("vagrant box update", shell=True)
    subprocess.run("vagrant up", shell=True)

    # Provision the VM.
    if args.provision == True:
        print("Provisioning VM")
        subprocess.run("vagrant provision", shell=True)

    # SSH into the VM.
    print("Running vagrant ssh.")
    subprocess.run("vagrant ssh", shell=True)
    print("Folder of Vagrantfile:",VAGRANTFULLFOLDERPATH)
