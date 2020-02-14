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

# Get arguments
parser = argparse.ArgumentParser(description='Install Fedora Software.')
parser.add_argument("-d", "--desktop", help='Desktop Environment (i.e. gnome, kde, mate, etc)')
parser.add_argument("-a", "--allextra", help='Run Extra Scripts', action="store_true")
parser.add_argument("-b", "--bare", help='Configure script to set up a bare-minimum environment.', action="store_true")
parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)
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
if not args.bare:
    # RPMFusion
    CFunc.dnfinstall("https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm")
    CFunc.dnfinstall("rpmfusion-nonfree-appstream-data rpmfusion-free-appstream-data")
    CFunc.dnfinstall("rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted")
    # Adobe Flash
    CFunc.dnfinstall("http://linuxdownload.adobe.com/adobe-release/adobe-release-$(uname -i)-1.0-1.noarch.rpm")
    CFunc.rpmimport("/etc/pki/rpm-gpg/RPM-GPG-KEY-adobe-linux")
    # Visual Studio Code
    CFunc.rpmimport("https://packages.microsoft.com/keys/microsoft.asc")
    with open("/etc/yum.repos.d/vscode.repo", 'w') as vscoderepofile_write:
        vscoderepofile_write.write('[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc"')
    # Balena Etcher
    CFunc.downloadfile("https://balena.io/etcher/static/etcher-rpm.repo", os.path.join(os.sep, "etc", "yum.repos.d"))


# Update system after enabling repos.
CFunc.dnfupdate()

### Install Fedora Software ###
# Cli tools
CFunc.dnfinstall("fish zsh nano tmux iotop rsync p7zip p7zip-plugins zip unzip xdg-utils xdg-user-dirs util-linux-user fuse-sshfs redhat-lsb-core openssh-server openssh-clients avahi dnf-plugin-system-upgrade")
if not args.bare:
    CFunc.dnfinstall("unrar")
subprocess.run("systemctl enable sshd", shell=True)
CFunc.dnfinstall("powerline-fonts google-roboto-fonts google-noto-sans-fonts")
# Samba
CFunc.dnfinstall("samba")
subprocess.run("systemctl enable smb", shell=True)
# cifs-utils
CFunc.dnfinstall("cifs-utils")
# Enable setuid for mount.cifs to enable mounting as a normal user
subprocess.run("sudo chmod u+s /sbin/mount.cifs", shell=True)
# NTP Configuration
subprocess.run("systemctl enable systemd-timesyncd; timedatectl set-local-rtc false; timedatectl set-ntp 1", shell=True)
# GUI Packages
if not args.nogui:
    CFunc.dnfinstall("@fonts @base-x @networkmanager-submodules")
    # Browsers
    # Official Chromium
    CFunc.dnfinstall("chromium")
    # Official Google Chrome
    # CFunc.dnfinstall("https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm")
    CFunc.dnfinstall("@firefox freshplayerplugin")
    CFunc.dnfinstall("flash-plugin")
    # Cups
    CFunc.dnfinstall("cups-pdf")
    # Audio/video
    CFunc.dnfinstall("pulseaudio-module-zeroconf pulseaudio-utils paprefs")
    # Remote access
    CFunc.dnfinstall("remmina remmina-plugins-vnc remmina-plugins-rdp")
    # Tilix
    CFunc.dnfinstall("tilix tilix-nautilus")
    if not args.bare:
        CFunc.dnfinstall("@multimedia")
        CFunc.dnfinstall("gstreamer1-vaapi gstreamer1-plugins-bad-nonfree")
        CFunc.dnfinstall("youtube-dl ffmpeg smplayer mpv")
        CFunc.dnfinstall("audacious audacious-plugins")
        # Editors
        CFunc.dnfinstall("code")
        # Etcher
        CFunc.dnfinstall("balena-etcher-electron")
        # Syncthing
        CFunc.dnfinstall("syncthing")
        # Flameshot
        CFunc.dnfinstall("flameshot")
        os.makedirs(os.path.join(USERHOME, ".config", "autostart"), exist_ok=True)
        # Start flameshot on user login.
        if os.path.isfile(os.path.join(os.sep, "usr", "share", "applications", "flameshot.desktop")):
            shutil.copy(os.path.join(os.sep, "usr", "share", "applications", "flameshot.desktop"), os.path.join(USERHOME, ".config", "autostart"))
        CFunc.chown_recursive(os.path.join(USERHOME, ".config", ), USERNAMEVAR, USERGROUP)

# Install software for VMs
if vmstatus == "kvm":
    CFunc.dnfinstall("spice-vdagent qemu-guest-agent")
if vmstatus == "vbox":
    CFunc.dnfinstall("virtualbox-guest-additions virtualbox-guest-additions-ogl")
if vmstatus == "vmware":
    CFunc.dnfinstall("open-vm-tools")
    if not args.nogui:
        CFunc.dnfinstall("open-vm-tools-desktop")

# Install Desktop Software
if args.desktop == "gnome":
    # Gnome
    CFunc.dnfinstall("--allowerasing @workstation-product @gnome-desktop")
    subprocess.run("systemctl enable -f gdm", shell=True)
    # Some Gnome Extensions
    CFunc.dnfinstall("gnome-terminal-nautilus gnome-tweak-tool dconf-editor")
    CFunc.dnfinstall("gnome-shell-extension-gpaste gnome-shell-extension-topicons-plus")
    # Install gs installer script.
    gs_installer = CFunc.downloadfile("https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer", os.path.join(os.sep, "usr", "local", "bin"), overwrite=True)
    os.chmod(gs_installer[0], 0o777)
    # Install volume extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 858".format(gs_installer[0]))
    # Install dashtodock extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 307".format(gs_installer[0]))
    # Install Do Not Disturb extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 1480".format(gs_installer[0]))
elif args.desktop == "kde":
    # KDE
    CFunc.dnfinstall("--allowerasing @kde-desktop-environment")
    CFunc.dnfinstall("ark latte-dock")
    subprocess.run("systemctl enable -f sddm", shell=True)
elif args.desktop == "mate":
    # MATE
    CFunc.dnfinstall("--allowerasing @mate-desktop @mate-applications")
    subprocess.run("systemctl enable -f lightdm", shell=True)
    # Applications
    CFunc.dnfinstall("dconf-editor")
    # Brisk-menu
    subprocess.run("dnf copr enable -y rmkrishna/rpms", shell=True)
    CFunc.dnfinstall("brisk-menu")
    # Run MATE Configuration
    subprocess.run("{0}/DExtMate.py -c".format(SCRIPTDIR), shell=True)
elif args.desktop == "xfce":
    CFunc.dnfinstall("--allowerasing @xfce-desktop-environment")
    CFunc.dnfinstall("xfce4-whiskermenu-plugin xfce4-systemload-plugin xfce4-diskperf-plugin xfce4-clipman-plugin")
elif args.desktop == "lxqt":
    CFunc.dnfinstall("--allowerasing @lxqt-desktop-environment")
elif args.desktop == "cinnamon":
    CFunc.dnfinstall("--allowerasing @cinnamon-desktop-environment")

if not args.nogui and not args.bare:
    # Numix
    CFunc.dnfinstall("numix-icon-theme-circle")
    # Update pixbuf cache after installing icons (for some reason doesn't do this automatically).
    subprocess.run("gdk-pixbuf-query-loaders-64 --update-cache", shell=True)

if not args.nogui:
    subprocess.run("systemctl set-default graphical.target", shell=True)

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

# Edit sudoers to add dnf.
fedora_sudoersfile = os.path.join(os.sep, "etc", "sudoers.d", "pkmgt")
CFunc.AddLineToSudoersFile(fedora_sudoersfile, "%wheel ALL=(ALL) ALL", overwrite=True)
CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("dnf")))

# Hdparm
CFunc.dnfinstall("smartmontools hdparm")

if not args.bare and not args.nogui:
    # Install snapd
    CFunc.dnfinstall("snapd")
    if not os.path.islink("/snap"):
        os.symlink("/var/lib/snapd/snap", "/snap", target_is_directory=True)
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("snap")))

    # Flatpak setup
    CFunc.dnfinstall("flatpak xdg-desktop-portal")
    CFunc.flatpak_addremote("flathub", "https://flathub.org/repo/flathub.flatpakrepo")
    CFunc.AddLineToSudoersFile(fedora_sudoersfile, "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("flatpak")))

    # Flatpak apps
    CFunc.flatpak_install("flathub", "org.keepassxc.KeePassXC")
    CFunc.flatpak_install("flathub", "org.videolan.VLC")
    CFunc.flatpak_install("flathub", "io.github.celluloid_player.Celluloid")
    CFunc.flatpak_install("flathub", "io.github.quodlibet.QuodLibet")

# Disable Selinux
# To get selinux status: sestatus, getenforce
# To enable or disable selinux temporarily: setenforce 1 (to enable), setenforce 0 (to disable)
subprocess.run("sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config /etc/sysconfig/selinux", shell=True)

# Disable the firewall
subprocess.run("systemctl mask firewalld", shell=True)

# Extra scripts
if args.allextra is True:
    subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CShellConfig.py -f -z -d".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CCSClone.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CVMGeneral.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Cxdgdirs.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

print("\nScript End")
