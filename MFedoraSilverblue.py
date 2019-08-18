#!/usr/bin/env python3
"""Install Fedora Software"""

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


### Functions ###
def rostreeupdate():
    """Update system"""
    print("\nPerforming system update.")
    subprocess.run("rpm-ostree upgrade", shell=True)
def rostreeinstall(apps):
    """Install application(s) using rpm-ostree"""
    status = None
    print("\nInstalling {0} using rpm-ostree.".format(apps))
    status = subprocess.run("rpm-ostree install --idempotent {0}".format(apps), shell=True).returncode
    return status


# Get arguments
parser = argparse.ArgumentParser(description='Install Fedora Software.')
parser.add_argument("-a", "--allextra", help='Run Extra Scripts', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Run extra scripts:", args.allextra)

# Exit if not root.
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)

# Get VM State
vmstatus = CFunc.getvmstate()

### Fedora Repos ###
# RPMFusion
rostreeinstall("https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm")
rostreeinstall("rpmfusion-nonfree-appstream-data rpmfusion-free-appstream-data")
rostreeinstall("rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted")


# Update system after enabling repos.
rostreeupdate()

### Install Fedora Software ###

### OSTree Apps ###
# Cli tools
rostreeinstall("zsh nano tmux iotop p7zip p7zip-plugins zip unzip xdg-utils xdg-user-dirs util-linux-user fuse-sshfs redhat-lsb-core openssh-server openssh-clients avahi")
subprocess.run("systemctl enable sshd", shell=True)
rostreeinstall("powerline-fonts google-roboto-fonts google-noto-sans-fonts")
# Samba
rostreeinstall("samba")
subprocess.run("systemctl enable smb", shell=True)
# NTP Configuration
subprocess.run("systemctl enable systemd-timesyncd; timedatectl set-local-rtc false; timedatectl set-ntp 1", shell=True)
# Hdparm
rostreeinstall("smartmontools hdparm")
# GUI Packages
# Cups
rostreeinstall("cups-pdf")
# Audio/video
rostreeinstall("pulseaudio-module-zeroconf pulseaudio-utils paprefs")
# Tilix
rostreeinstall("tilix tilix-nautilus")
# Syncthing
rostreeinstall("syncthing")

# Install software for VMs
if vmstatus == "kvm":
    rostreeinstall("spice-vdagent qemu-guest-agent")
if vmstatus == "vbox":
    rostreeinstall("virtualbox-guest-additions virtualbox-guest-additions-ogl")
if vmstatus == "vmware":
    rostreeinstall("open-vm-tools")
    if not args.nogui:
        rostreeinstall("open-vm-tools-desktop")

# Install Desktop Software
# Some Gnome Extensions
rostreeinstall("gnome-tweak-tool dconf-editor")
rostreeinstall("gnome-shell-extension-gpaste gnome-shell-extension-topicons-plus gnome-shell-extension-dash-to-dock")
# Install gs installer script.
gs_installer = CFunc.downloadfile("https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer", os.path.join(os.sep, "usr", "local", "bin"), overwrite=True)
os.chmod(gs_installer[0], 0o777)
# Install volume extension
CFunc.run_as_user(USERNAMEVAR, "{0} --yes 858".format(gs_installer[0]))


# Add normal user to all reasonable groups
# TODO: Change to specific groups, added one at a time.

sudoers_script = """
# Delete defaults in sudoers.
if grep -iq $'^Defaults    secure_path' /etc/sudoers; then
    sed -e 's/^Defaults    env_reset$/Defaults    !env_reset/g' -i /etc/sudoers
    sed -i $'/^Defaults    mail_badpass/ s/^#*/#/' /etc/sudoers
    sed -i $'/^Defaults    secure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c
"""
subprocess.run(sudoers_script, shell=True)

# Edit sudoers to add commands.
if os.path.isdir('/etc/sudoers.d'):
    CUSTOMSUDOERSPATH = "/etc/sudoers.d/pkmgt"
    print("Writing {0}".format(CUSTOMSUDOERSPATH))
    with open(CUSTOMSUDOERSPATH, 'w') as sudoers_writefile:
        sudoers_writefile.write("""%wheel ALL=(ALL) ALL
{0} ALL=(ALL) NOPASSWD: {1}, {2}
""".format(USERNAMEVAR, shutil.which("flatpak"), shutil.which("rpm-ostree")))
    os.chmod(CUSTOMSUDOERSPATH, 0o440)
    vsudo_status = subprocess.run('visudo -c', shell=True)
    if vsudo_status.returncode != 0:
        print("Visudo status not 0, removing sudoers file.")
        os.remove(CUSTOMSUDOERSPATH)

# Install snapd
rostreeinstall("snapd")
if not os.path.islink("/snap"):
    os.symlink("/var/lib/snapd/snap", "/snap", target_is_directory=True)

# Flatpak setup
rostreeinstall("flatpak xdg-desktop-portal")
CFunc.flatpak_addremote("flathub", "https://flathub.org/repo/flathub.flatpakrepo")

# Flatpak apps
CFunc.flatpak_install("flathub", "org.videolan.VLC")
CFunc.flatpak_install("flathub", "io.github.celluloid_player.Celluloid")

# Disable Selinux
# To get selinux status: sestatus, getenforce
# To enable or disable selinux temporarily: setenforce 1 (to enable), setenforce 0 (to disable)
subprocess.run("sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config /etc/sysconfig/selinux", shell=True)

# Disable the firewall
subprocess.run("systemctl mask firewalld", shell=True)

# Extra scripts
if args.allextra is True:
    subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CShellConfig.py -z -d".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CCSClone.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CVMGeneral.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Cxdgdirs.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

print("\nScript End")
