#!/usr/bin/env python3
"""Install FreeBSD Software"""

# Python includes.
import argparse
from datetime import datetime
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
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)
# Time script was started.
time_start = datetime.now()

# Override FreeBSD Quarterly repo with latest repo
os.makedirs("/usr/local/etc/pkg/repos", exist_ok=True)
with open("/usr/local/etc/pkg/repos/FreeBSD.conf", 'w') as file:
    file.write('FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/latest" }')

# Update ports in background
process_portupdate = subprocess.Popen("portsnap --interactive auto", shell=True, stdout=subprocess.DEVNULL, close_fds=True)
# Update system
subprocess.run(["freebsd-update", "--not-running-from-cron", "fetch", "install"])
# Update packages
subprocess.run(["pkg", "update", "-f"])

# Get VM State
pkg_install("dmidecode")
vmstatus = CFunc.getvmstate()


### Install FreeBSD Software ###
# Cli tools
pkg_install("git python3 sudo nano bash zsh tmux rsync wget p7zip p7zip-codec-rar zip unzip xdg-utils xdg-user-dirs fusefs-sshfs avahi-app")
pkg_install("powerline-fonts ubuntu-font roboto-fonts-ttf noto-lite liberation-fonts-ttf")
# Portmaster
pkg_install("portmaster")
# Samba
pkg_install("samba46")
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
    pkg_install("remmina remmina-plugins remmina-plugin-vnc remmina-plugin-rdp")
    # Editors
    pkg_install("geany")
    # Terminator
    pkg_install("terminator")

# Install software for VMs
if vmstatus == "vbox":
    pkg_install("virtualbox-ose-additions")
    sysrc_cmd('vboxguest_enable=yes vboxservice_enable=yes')
if vmstatus == "vmware":
    pkg_install("open-vm-tools")

# Install Desktop Software
if not args.nogui:
    pkg_install("xorg xorg-drivers")
    sysrc_cmd("moused_enable=yes dbus_enable=yes hald_enable=yes")
if args.desktop == "gnome":
    pkg_install("gnome3")
    sysrc_cmd('gdm_enable=yes')
    sysrc_cmd('slim_enable=')
    slim_session_name = "gnome-session"
    pkg_install("gnome-shell-extension-dashtodock")
    subprocess.run("glib-compile-schemas /usr/local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas", shell=True)
elif args.desktop == "mate":
    pkg_install("mate")
    # Setup slim
    slim_session_name = "mate-session"
elif args.desktop == "lumina":
    pkg_install("lumina")
    slim_session_name = "lumina-session"
# Install slim
if args.desktop != "gnome":
    pkg_install("slim")
    sysrc_cmd('slim_enable=yes')
    sysrc_cmd('gdm_enable=')
    # Setup slim
    with open(os.path.join("/", "root", ".xinitrc"), 'w') as file:
        file.write("exec {0}".format(slim_session_name))
    with open(os.path.join(USERHOME, ".xinitrc"), 'w') as file:
        file.write("exec {0}".format(slim_session_name))

# Post-desktop installs
if not args.nogui:
    # Numix Icons
    iconfolder = os.path.join("/", "usr", "local", "share", "icons")
    os.makedirs(iconfolder, exist_ok=True)
    # Numix icons must be installed for Circle to display properly.
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix-Light"), ignore_errors=True)
    subprocess.run("git clone https://github.com/numixproject/numix-icon-theme.git {0}".format(os.path.join(iconfolder, "numix-icon-theme")), shell=True)
    shutil.move(os.path.join(iconfolder, "numix-icon-theme", "Numix"), iconfolder)
    shutil.move(os.path.join(iconfolder, "numix-icon-theme", "Numix-Light"), iconfolder)
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme"), ignore_errors=True)
    # Numix Circle Icons
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme-circle"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix-Circle"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix-Circle-Light"), ignore_errors=True)
    subprocess.run("git clone https://github.com/numixproject/numix-icon-theme-circle.git {0}".format(os.path.join(iconfolder, "numix-icon-theme-circle")), shell=True)
    shutil.move(os.path.join(iconfolder, "numix-icon-theme-circle", "Numix-Circle"), iconfolder)
    shutil.move(os.path.join(iconfolder, "numix-icon-theme-circle", "Numix-Circle-Light"), iconfolder)
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme-circle"), ignore_errors=True)
    subprocess.run("gtk-update-icon-cache {0}".format(os.path.join(iconfolder, "/Numix-Circle")), shell=True)

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
subprocess.run("pw usermod {0} -G wheel,video,operator".format(USERNAMEVAR), shell=True)

# Extra scripts
if args.allextra is True:
    subprocess.run("bash {0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CShellConfig.py -z".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CCSClone.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("bash {0}/CVMGeneral.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Cxdgdirs.py".format(SCRIPTDIR), shell=True)
    subprocess.run("bash {0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

# Wait for processes to finish before exiting.
time_finishmain = datetime.now()
process_portupdate.wait()
time_finishport = datetime.now()

print("\nPre-port update finished in {0}".format(str(time_finishmain - time_start)))
print("Script End in {0}".format(str(time_finishport - time_start)))
