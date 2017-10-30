#!/usr/bin/env python3
"""Configure Samba and other network services"""

# Python includes.
import argparse
import getpass
import grp
import os
import platform
import pwd
import subprocess
import sys

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Docker.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-p", "--password", help='Set the password if not read from a file.', default="asdf")
parser.add_argument("-d", "--passfilepath", help='Set the password full file path when reading from a file.', default="/var/tmp/sambapass.txt")
parser.add_argument("-f", "--force", help='Force setting the samba password.', action="store_true")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
if os.getenv("SUDO_USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("SUDO_USER")
elif os.getenv("USER") not in ["root", None]:
    USERNAMEVAR = os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR = pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP = grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
USERHOME = os.path.expanduser("~{0}".format(USERNAMEVAR))
MACHINEARCH = platform.machine()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


### Functions ###
def subpout(cmd):
    """Get output from subprocess"""
    output = subprocess.run("{0}".format(cmd), shell=True, stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return output

# Temp code write password to file
with open(args.passfilepath, 'w') as VAR:
    VAR.write(args.password)

# Use sambapass file if it exists
if os.path.exists(args.passfilepath) and os.path.isfile(args.passfilepath):
    with open(args.passfilepath, 'r') as VAR:
        SAMBAPASS = VAR.read().strip()
    print("Using password detected from {0}.".format(args.passfilepath))
else:
    print("Using password passed as an argument.")
    SAMBAPASS = args.password

if SAMBAPASS == "asdf":
    print("\nWARNING: Insecure default password is used. Ensure this is what you really want.")


if args.noprompt is False:
    if SAMBAPASS == "asdf" or SAMBAPASS is None:
        SAMBAPASS = getpass.getpass(prompt='Please enter a samba password:')
    input("Press Enter to continue.")


# Set samba password for given user.
pdbout = subpout("pdbedit -L")
if USERNAMEVAR not in pdbout or args.force is True:
    print("Setting samba password for {0}.".format(USERNAMEVAR))
    # Use a subprocess pipe to feed the password in.
    pdbproc = subprocess.run(['pdbedit', '-a', '-u', USERNAMEVAR, '-t'], stdout=subprocess.PIPE, input=SAMBAPASS+"\n"+SAMBAPASS, encoding='ascii')
    print(pdbproc.stdout.strip())
else:
    print("Password already set for user {0}. Skipping.".format(USERNAMEVAR))

# Remove sambapass file if it exists
if os.path.exists(args.passfilepath) and os.path.isfile(args.passfilepath):
    os.remove(args.passfilepath)
