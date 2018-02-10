#!/usr/bin/env python3
"""Install Display Manager Configuration."""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Create synergy-core configuration.')
parser.add_argument("-a", "--autologin", help='Force automatic login in display managers.', action="store_true")

# Save arguments.
args = parser.parse_args()

# Get VM State
vmstatus = CFunc.getvmstate()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


### LightDM Section ###
if shutil.which("lightdm"):
    print("\n Processing lightdm configuration.")
    if not "autologin" in open('/etc/group', 'r').read():
        subprocess.run("groupadd autologin", shell=True)
    subprocess.run("gpasswd -a {0} autologin".format(USERNAMEVAR), shell=True)
    # Enable autologin
    if vmstatus or args.autologin is True:
        if os.path.isfile("/etc/lightdm/lightdm.conf"):
            subprocess.run("sed -i 's/#autologin-user=/autologin-user={0}/g' /etc/lightdm/lightdm.conf".format(USERNAMEVAR), shell=True)
        os.makedirs("/etc/lightdm/lightdm.conf.d", exist_ok=True)
        subprocess.run('echo -e "[SeatDefaults]\nautologin-user={0}" > /etc/lightdm/lightdm.conf.d/12-autologin.conf'.format(USERNAMEVAR), shell=True)
if os.path.isfile("/etc/lightdm/lightdm.conf"):
    subprocess.run("sed -i 's/#greeter-hide-users=false/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf", shell=True)

### GDM Section ###


### SDDM Section ###
if shutil.which("sddm"):
    print("\n Processing sddm configuration.")
    # Enable autologin
    if vmstatus or args.autologin is True:
        os.makedirs("/etc/sddm.conf.d", exist_ok=True)
        with open("/etc/sddm.conf.d/autologin.conf", 'w') as f:
            f.write("""[Autologin]
User={0}
Session=plasma.desktop
""".format(USERNAMEVAR))
