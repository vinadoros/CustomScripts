#!/usr/bin/env python3
"""Install Fedora Software"""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
import time
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
    subprocess.run("rpm-ostree upgrade", shell=True, check=True)
def rostreeinstall(apps):
    """Install application(s) using rpm-ostree"""
    status = None
    print("\nInstalling {0} using rpm-ostree.".format(apps))
    status = subprocess.run("rpm-ostree install --idempotent --allow-inactive {0}".format(apps), shell=True, check=True).returncode
    return status
def systemd_resostreed():
    """Restart the rpm-ostreed service. This is needed in case it is doing something during this script operation, which would prevent the script from running. Restart the service before rpm-ostree operations."""
    subprocess.run("systemctl restart rpm-ostreed", shell=True, check=True)
    time.sleep(1)


# Get arguments
parser = argparse.ArgumentParser(description='Install Fedora Silverblue Software.')
parser.add_argument("-s", "--stage", help='Stage of installation to run (1 or 2).', type=int, default=0)

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
    systemd_resostreed()

    ### Fedora Repos ###
    # RPMFusion
    rostreeinstall("https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm")

    # Update system.
    rostreeupdate()

    ### OSTree Apps ###
    # Cli tools
    rostreeinstall("fish zsh tmux iotop p7zip p7zip-plugins util-linux-user fuse-sshfs redhat-lsb-core powerline-fonts google-roboto-fonts google-noto-sans-fonts samba smartmontools hdparm cups-pdf pulseaudio-module-zeroconf paprefs tilix tilix-nautilus syncthing numix-icon-theme numix-icon-theme-circle")
    subprocess.run("systemctl enable sshd", shell=True, check=True)
    # NTP Configuration
    subprocess.run("systemctl enable systemd-timesyncd; timedatectl set-local-rtc false; timedatectl set-ntp 1", shell=True, check=True)

    # Install software for VMs
    if vmstatus == "vbox":
        rostreeinstall("virtualbox-guest-additions virtualbox-guest-additions-ogl")
    if vmstatus == "vmware":
        rostreeinstall("open-vm-tools open-vm-tools-desktop")

    # Some Gnome Extensions
    rostreeinstall("gnome-tweak-tool dconf-editor")
    rostreeinstall("gnome-shell-extension-gpaste gnome-shell-extension-topicons-plus")

    # Sudoers changes
    CFuncExt.SudoersEnvSettings()
    # Edit sudoers to add dnf.
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "%wheel ALL=(ALL) ALL", overwrite=True)
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("rpm-ostree")))

    # Install snapd
    rostreeinstall("snapd")

    # Flatpak setup
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("flatpak")))
    subprocess.run('chmod -R "ugo=rwX" /var/lib/flatpak/', shell=True, check=True)

    # Disable Selinux
    # To get selinux status: sestatus, getenforce
    subprocess.run("rpm-ostree kargs --append=selinux=0", shell=True, check=True)

    # firewalld
    CFunc.sysctl_enable("firewalld", now=True, error_on_fail=True)
    CFuncExt.FirewalldConfig()

    # Disable mitigations
    subprocess.run("rpm-ostree kargs --append=mitigations=off", shell=True, check=True)
    print("Stage 1 Complete! Please reboot and run Stage 2.")
if args.stage == 2:
    print("Stage 2")
    systemd_resostreed()
    rostreeinstall("rpmfusion-nonfree-appstream-data rpmfusion-free-appstream-data")
    rostreeinstall("rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted")
    subprocess.run("systemctl enable smb", shell=True, check=True)

    # Install gs installer script.
    gs_installer = CFunc.downloadfile("https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer", os.path.join(os.sep, "usr", "local", "bin"), overwrite=True)
    os.chmod(gs_installer[0], 0o777)
    # Install volume extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 858".format(gs_installer[0]))
    # Install dashtodock extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 307".format(gs_installer[0]))

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
    if not args.nogui:
        subprocess.run(os.path.join(SCRIPTDIR, "CFlatpakConfig.py"), shell=True, check=True)
    CFunc.flatpak_install("fedora", "org.gnome.gedit")
    CFunc.flatpak_install("fedora", "org.gnome.Evince")
    CFunc.flatpak_install("fedora", "org.gnome.eog")
    CFunc.flatpak_install("flathub", "com.visualstudio.code-oss")

    # Extra scripts
    subprocess.run("{0}/CCSClone.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CShellConfig.py -z -d".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CVMGeneral.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/Cxdgdirs.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True, check=True)
    subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True, check=True)
    print("Stage 2 complete! Please reboot.")

print("\nScript End")
