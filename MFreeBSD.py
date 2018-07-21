#!/usr/bin/env python3
"""Install FreeBSD Software"""

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
parser = argparse.ArgumentParser(description='Install FreeBSD Software.')
parser.add_argument("-d", "--desktop", help='Desktop Environment (i.e. gnome, kde, mate, etc)')
parser.add_argument("-a", "--allextra", help='Run Extra Scripts', action="store_true")
parser.add_argument("-b", "--bare", help='Configure script to set up a bare-minimum environment.', action="store_true")
parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)
print("Run extra scripts:", args.allextra)


### Functions ###
def pkg_install(packages):
    """Installl package using pkg"""
    subprocess.run("pkg install -y {0}".format(packages), shell=True)
    return
def sysrc_cmd(cmd):
    """Run command for sysrc"""
    subprocess.run("sysrc {0}".format(cmd), shell=True)
    return


# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)

# Update system
subprocess.run(["freebsd-update", "--not-running-from-cron", "fetch", "install"])
# Update packages
subprocess.run(["pkg", "update", "-f"])

# Get VM State
pkg_install("dmidecode")
vmstatus = CFunc.subpout("dmidecode -s baseboard-product-name")


### Install FreeBSD Software ###
# Cli tools
pkg_install("git python3 sudo nano bash zsh tmux rsync p7zip p7zip-codec-rar zip unzip xdg-utils xdg-user-dirs fusefs-sshfs avahi-app")
pkg_install("powerline-fonts ubuntu-font roboto-fonts-ttf noto-lite")
# Samba
pkg_install("samba48")
sysrc_cmd('samba_server_enable=yes winbindd_enable=yes')
# NTP Configuration
sysrc_cmd('ntpd_enable=yes')
# GUI Packages
if not args.nogui:
    # Browsers
    pkg_install("chromium firefox")
    # Wine
    pkg_install("wine-devel wine-gecko-devel wine-mono-devel winetricks")
    # Remote access
    pkg_install("remmina remmina-plugin-vnc remmina-plugin-rdp")

# Install software for VMs
if vmstatus == "VirtualBox":
    pkg_install("virtualbox-ose-additions")
    sysrc_cmd('vboxguest_enable=yes vboxservice_enable=yes')
if vmstatus == "VMware":
    pkg_install("open-vm-tools")

# Install Desktop Software
if not args.nogui:
    pkg_install("xorg xorg-drivers")
    sysrc_cmd("moused_enable=yes dbus_enable=yes hald_enable=yes")
if args.desktop == "gnome":
    # Gnome
    pkg_install("gnome")
    sysrc_cmd('gdm_enable=yes')
elif args.desktop == "mate":
    # MATE
    pkg_install("mate slim")
    sysrc_cmd('slim_enable=yes')
    # Setup slim
    with open(os.path.join("/", "root", ".xinitrc"), 'w') as file:
        file.write("exec mate-session")
    with open(os.path.join(USERHOME, ".xinitrc"), 'w') as file:
        file.write("exec mate-session")


# Edit sudoers to add pkg.
sudoersd_dir = os.path.join("/", "usr", "local", "etc", "sudoers.d")
if os.path.isdir(sudoersd_dir):
    CUSTOMSUDOERSPATH = os.path.join(sudoersd_dir, "10-wheel")
    print("Writing {0}".format(CUSTOMSUDOERSPATH))
    with open(CUSTOMSUDOERSPATH, 'w') as sudoers_writefile:
        sudoers_writefile.write("""%wheel ALL=(ALL) ALL
{0} ALL=(ALL) NOPASSWD: {1}
""".format(USERNAMEVAR, shutil.which("pkg")))
    os.chmod(CUSTOMSUDOERSPATH, 0o440)
    status = subprocess.run('visudo -c', shell=True)
    if status.returncode is not 0:
        print("Visudo status not 0, removing sudoers file.")
        os.remove(CUSTOMSUDOERSPATH)
subprocess.run("pw usermod {0} -G wheel,video".format(USERNAMEVAR))

# Extra scripts
if args.allextra is True:
    subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CShellConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CCSClone.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CVMGeneral.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Cxdgdirs.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

print("\nScript End")
