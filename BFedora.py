#!/usr/bin/env python3

# Python includes.
import argparse
import os
import sys
import subprocess

# Get arguments
parser = argparse.ArgumentParser(description='Install Fedora into a folder/chroot.')
parser.add_argument("-n", "--noprompt",help='Do not prompt to continue.', action="store_true")
parser.add_argument("-c", "--hostname", dest="hostname", help='Hostname', default="FedoraTest")
parser.add_argument("-u", "--username", dest="username", help='Username', default="user")
parser.add_argument("-f", "--fullname", dest="fullname", help='Full Name', default="User Name")
parser.add_argument("-q", "--password", dest="password", help='Password', default="asdf")
parser.add_argument("-g", "--grub", type=int, dest="grubtype", help='Grub Install Number', default=1)
parser.add_argument("-t", "--type", dest="type", help='Type of release (fedora, centos, etc)', default="fedora")
parser.add_argument("-v", "--version", dest="version", help='Version of Release', default=24)
parser.add_argument("installpath", help='Path of Installation')

# Save arguments.
args = parser.parse_args()
print("Hostname:",args.hostname)
print("Username:",args.username)
print("Full Name:",args.fullname)
print("Grub Install Number:",args.grubtype)
print("Path of Installation:",args.installpath)
print("Type of release:",args.type)
print("Version of Release:",args.version)

# Exit if not root.
if not os.geteuid() == 0:
    sys.exit("\nError: Please run this script as root.\n")

if args.noprompt == False:
    input("Press Enter to continue.")

# subprocess.run("dnf --releasever="+args.version+"--installroot=" +args.installpath+" --assumeyes install kernel kernel-modules kernel-modules-extra @workstation-product @gnome-desktop @core @hardware-support @networkmanager-submodules @fonts @base-x grub2", shell=True)
