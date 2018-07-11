#!/usr/bin/env python3
"""Test script for Pkvm.py"""

# Python includes.
import argparse
from datetime import datetime
import logging
import multiprocessing
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

### Functions ###
def pkvm_cmd_generate():
    CFunc.subpout_logger("{pkvm_path}".format(pkvm_path=pkvm_path))
    return


# Exit if root.
CFunc.is_root(False)

# Get arguments
parser = argparse.ArgumentParser(description='Test Pkvm.py.')
parser.add_argument("-t", "--vmtype", type=int, help="VM Hypervisor to generate (1=Virtualbox, 2=libvirt, 3=VMWare, 4=hyperv, 0=all)", default="0")
parser.add_argument("-w", "--winiso", help="Path to Windows ISOs")
parser.add_argument("-s", "--imgsize", type=int, help="Size of images", default=65536)
parser.add_argument("-p", "--vmpath", help="Path of Packer output", required=True)
parser.add_argument("-y", "--vmuser", help="VM Usernames", default="user")
parser.add_argument("-z", "--vmpass", help="VM Passwords", default="asdf")
parser.add_argument("-d", "--debug", help="Enable Debug output from packer", action="store_true")
parser.add_argument("--memory", help="Memory for VMs", default="4096")

# Save arguments.
args = parser.parse_args()

# Parse options
t_vbox = False
t_libvirt = False
t_vmware = False
t_hyperv = False
if args.vmtype == 0:
    t_vbox = True
    if CFunc.is_windows() is not True:
        t_libvirt = True
elif args.vmtype == 1:
    t_vbox = True
elif args.vmtype == 2:
    t_libvirt = True
elif args.vmtype == 3:
    t_vmware = True
elif args.vmtype == 4:
    t_hyperv = True
print("Testing Virtualbox: {0}".format(t_vbox))
print("Testing Libvirt: {0}".format(t_libvirt))
print("Testing Vmware: {0}".format(t_vmware))
print("Testing Hyper-V: {0}".format(t_hyperv))
# Path to pkvm script.
pkvm_path = os.path.join(SCRIPTDIR, "Pkvm.py")

# Setup
# Initiate logger
starttime = datetime.now()
buildlog_path = os.path.join("vmtest{0}.log".format(str(starttime)))
CFunc.log_config(buildlog_path)

# Generate and run Packer arguments
if t_vbox:
    print("\n\nTesting Virtualbox")
if t_libvirt:
    print("\n\nTesting libvirt")
if t_vmware:
    print("\n\nTesting Vmware")
if t_hyperv:
    print("\n\nTesting Hyper-V")
