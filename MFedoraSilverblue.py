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
import CFuncExt

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
    status = subprocess.run("rpm-ostree install --idempotent --allow-inactive {0}".format(apps), shell=True).returncode
    return status


# Get arguments
parser = argparse.ArgumentParser(description='Install Fedora Silverblue Software.')
parser.add_argument("-s", "--stage", help='Stage of installation to run.', type=int, default=0)

# Save arguments.
args = parser.parse_args()
print("Stage:", args.stage)

# Exit if not root.
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)

# Get VM State
vmstatus = CFunc.getvmstate()


### Begin Code ###
fedora_sudoersfile = os.path.join(os.sep, "etc", "sudoers.d", "pkmgt")
if args.stage == 0:
    print("Please select a stage.")
if args.stage == 1:
    print("Stage 1")

    ### Fedora Repos ###
    # RPMFusion
    rostreeinstall("https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm")

    # Update system.
    rostreeupdate()

    ### OSTree Apps ###
    # Cli tools
    rostreeinstall("zsh nano tmux iotop p7zip p7zip-plugins util-linux-user fuse-sshfs redhat-lsb-core dbus-tools powerline-fonts google-roboto-fonts google-noto-sans-fonts samba smartmontools hdparm cups-pdf pulseaudio-module-zeroconf paprefs tilix tilix-nautilus syncthing numix-icon-theme numix-icon-theme-circle")
    subprocess.run("systemctl enable sshd", shell=True)
    # NTP Configuration
    subprocess.run("systemctl enable systemd-timesyncd; timedatectl set-local-rtc false; timedatectl set-ntp 1", shell=True)

    # Install software for VMs
    if vmstatus == "vbox":
        rostreeinstall("virtualbox-guest-additions virtualbox-guest-additions-ogl")
    if vmstatus == "vmware":
        rostreeinstall("open-vm-tools open-vm-tools-desktop")

    # Some Gnome Extensions
    rostreeinstall("gnome-tweak-tool dconf-editor")
    rostreeinstall("gnome-shell-extension-gpaste gnome-shell-extension-topicons-plus gnome-shell-extension-dash-to-dock")

    # Sudoers changes
    CFuncExt.SudoersEnvSettings()
    # Edit sudoers to add dnf.
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "%wheel ALL=(ALL) ALL", overwrite=True)
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("rpm-ostree")))

    # Install snapd
    rostreeinstall("snapd")

    # Flatpak setup
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("flatpak")))
    CFunc.flatpak_addremote("flathub", "https://flathub.org/repo/flathub.flatpakrepo")
    subprocess.run('chmod -R "ugo=rwX" /var/lib/flatpak/', shell=True)

    # Disable Selinux
    # To get selinux status: sestatus, getenforce
    # To enable or disable selinux temporarily: setenforce 1 (to enable), setenforce 0 (to disable)
    subprocess.run("sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config /etc/sysconfig/selinux", shell=True)

    # Disable the firewall
    subprocess.run("systemctl mask firewalld", shell=True)

    # Disable mitigations
    subprocess.run("rpm-ostree kargs --append=mitigations=off", shell=True)

if args.stage == 2:
    print("Stage 2")
    rostreeinstall("rpmfusion-nonfree-appstream-data rpmfusion-free-appstream-data")
    rostreeinstall("rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted")
    subprocess.run("systemctl enable smb", shell=True)

    # Install gs installer script.
    gs_installer = CFunc.downloadfile("https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer", os.path.join(os.sep, "usr", "local", "bin"), overwrite=True)
    os.chmod(gs_installer[0], 0o777)
    # Install volume extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 858".format(gs_installer[0]))

    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("snap")))

    # Add normal user to all reasonable groups
    CFunc.AddUserToGroup("disk")
    CFunc.AddUserToGroup("lp")
    CFunc.AddUserToGroup("wheel")
    CFunc.AddUserToGroup("cdrom")
    CFunc.AddUserToGroup("man")
    CFunc.AddUserToGroup("dialout")
    CFunc.AddUserToGroup("floppy")
    CFunc.AddUserToGroup("games")
    CFunc.AddUserToGroup("tape")
    CFunc.AddUserToGroup("video")
    CFunc.AddUserToGroup("audio")
    CFunc.AddUserToGroup("input")
    CFunc.AddUserToGroup("kvm")
    CFunc.AddUserToGroup("systemd-journal")
    CFunc.AddUserToGroup("systemd-network")
    CFunc.AddUserToGroup("systemd-resolve")
    CFunc.AddUserToGroup("systemd-timesync")
    CFunc.AddUserToGroup("pipewire")
    CFunc.AddUserToGroup("colord")
    CFunc.AddUserToGroup("nm-openconnect")
    CFunc.AddUserToGroup("vboxsf")

    # Flatpak apps
    CFunc.flatpak_install("fedora", "org.gnome.gedit")
    CFunc.flatpak_install("fedora", "org.gnome.Evince")
    CFunc.flatpak_install("fedora", "org.gnome.eog")
    CFunc.flatpak_install("flathub", "org.keepassxc.KeePassXC")
    CFunc.flatpak_install("flathub", "org.videolan.VLC")
    CFunc.flatpak_install("flathub", "io.github.quodlibet.QuodLibet")
    CFunc.flatpak_install("flathub", "com.visualstudio.code.oss")

    # Extra scripts
    subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CShellConfig.py -z -d".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CCSClone.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CVMGeneral.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Cxdgdirs.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

print("\nScript End")
