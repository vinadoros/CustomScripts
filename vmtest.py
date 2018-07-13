#!/usr/bin/env python3
"""Test script for Pkvm.py"""

# Python includes.
import argparse
from datetime import datetime
import os
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

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
parser.add_argument("--excludewindows", help="Do not test Windows VMs", action="store_true")
parser.add_argument("-v", "--vmnumber", help="Spin up only the selected VM", action="store_true")
parser.add_argument("--memory", help="Memory for VMs", default="4096")

# Save arguments.
args = parser.parse_args()

### Functions ###
def pkvm_cmd_generate(pkvm_path, vmpath, type, os, vmname, desktopenv="mate", vmuser=args.vmuser, vmpass=args.vmpass, iso=None):
    # Generate the command
    pkvm_cmd = "{0}".format(pkvm_path)
    pkvm_cmd += " -m"
    pkvm_cmd += " -p {0}".format(vmpath)
    pkvm_cmd += " -t {0}".format(type)
    pkvm_cmd += " -a {0}".format(os)
    pkvm_cmd += " -y {0}".format(vmuser)
    pkvm_cmd += " -z {0}".format(vmpass)
    pkvm_cmd += " -n {0}".format(vmname)
    pkvm_cmd += " -e {0}".format(desktopenv)
    if iso is not None:
        pkvm_cmd = " -i {0}".format(iso)
    # Run Pkvm.py
    CFunc.subpout_logger(pkvm_cmd)
    return
# def pkvm_vmlist()


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
# Path to Windows isos
if args.winiso is not None:
    winiso_path = os.path.join()
else:
    winiso_path = None
vmpath = os.path.abspath(args.vmpath)

# Setup
# Initiate logger
starttime = datetime.now()
buildlog_path = os.path.join(vmpath, "vmtest_{0}.log".format(str(starttime.strftime("%Y%m%d-%H%M"))))
CFunc.log_config(buildlog_path)

# Generate and run Packer arguments
if t_vbox:
    print("\n\nTesting Virtualbox")
    pkvm_cmd_generate(pkvm_path, vmpath, 1, 1, "vmtest-vbox-{0}-FedoraGnome".format(starttime.strftime("%Y%m%d-%H%M")), "gnome")
    pkvm_cmd_generate(pkvm_path, vmpath, 1, 1, "vmtest-vbox-{0}-FedoraMate".format(starttime.strftime("%Y%m%d-%H%M")), "mate")
    pkvm_cmd_generate(pkvm_path, vmpath, 1, 10, "vmtest-vbox-{0}-UbuntuGnome".format(starttime.strftime("%Y%m%d-%H%M")), "gnome")
    pkvm_cmd_generate(pkvm_path, vmpath, 1, 10, "vmtest-vbox-{0}-UbuntuMate".format(starttime.strftime("%Y%m%d-%H%M")), "mate")
if t_libvirt:
    print("\n\nTesting libvirt")
    pkvm_cmd_generate(pkvm_path, vmpath, 2, 1, "vmtest-libvirt-{0}-FedoraGnome".format(starttime.strftime("%Y%m%d-%H%M")), "gnome")
    pkvm_cmd_generate(pkvm_path, vmpath, 2, 1, "vmtest-libvirt-{0}-FedoraMate".format(starttime.strftime("%Y%m%d-%H%M")), "mate")
    pkvm_cmd_generate(pkvm_path, vmpath, 2, 10, "vmtest-libvirt-{0}-UbuntuGnome".format(starttime.strftime("%Y%m%d-%H%M")), "gnome")
    pkvm_cmd_generate(pkvm_path, vmpath, 2, 10, "vmtest-libvirt-{0}-UbuntuMate".format(starttime.strftime("%Y%m%d-%H%M")), "mate")
if t_vmware:
    print("\n\nTesting Vmware")
if t_hyperv:
    print("\n\nTesting Hyper-V")

# If no VM number is specified, run all of them.
# if args.vmnumber is None:
#
# else:
