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
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

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
    # Adobe Flash
    CFunc.dnfinstall("http://linuxdownload.adobe.com/adobe-release/adobe-release-$(uname -i)-1.0-1.noarch.rpm")
    CFunc.rpmimport("/etc/pki/rpm-gpg/RPM-GPG-KEY-adobe-linux")
    # Visual Studio Code
    CFunc.rpmimport("https://packages.microsoft.com/keys/microsoft.asc")
    with open("/etc/yum.repos.d/vscode.repo", 'w') as vscoderepofile_write:
        vscoderepofile_write.write('[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc"')
    # Adapta
    subprocess.run('dnf copr enable -y heikoada/gtk-themes', shell=True)


# Update system after enabling repos.
CFunc.dnfupdate()

### Install Fedora Software ###
# Cli tools
CFunc.dnfinstall("zsh nano tmux iotop rsync p7zip p7zip-plugins zip unzip xdg-utils xdg-user-dirs util-linux-user fuse-sshfs redhat-lsb-core openssh-server openssh-clients avahi dnf-plugin-system-upgrade")
if not args.bare:
    CFunc.dnfinstall("unrar")
subprocess.run("systemctl enable sshd", shell=True)
CFunc.dnfinstall("powerline-fonts google-roboto-fonts google-noto-sans-fonts")
# Samba
CFunc.dnfinstall("samba")
subprocess.run("systemctl enable smb", shell=True)
# NTP Configuration
subprocess.run("systemctl enable systemd-timesyncd; timedatectl set-local-rtc false; timedatectl set-ntp 1", shell=True)
# GUI Packages
if not args.nogui:
    CFunc.dnfinstall("@fonts @base-x @networkmanager-submodules")
    # Management tools
    CFunc.dnfinstall("yumex-dnf dnfdragora dnfdragora-gui gparted")
    # Browsers
    CFunc.dnfinstall("https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm")
    CFunc.dnfinstall("@firefox freshplayerplugin")
    CFunc.dnfinstall("flash-plugin")
    # Cups
    CFunc.dnfinstall("cups-pdf")
    # Wine
    CFunc.dnfinstall("wine wine.i686 winetricks playonlinux")
    # Audio/video
    CFunc.dnfinstall("pulseaudio-module-zeroconf pulseaudio-utils paprefs ladspa-swh-plugins")
    # Remote access
    CFunc.dnfinstall("remmina remmina-plugins-vnc remmina-plugins-rdp")
    # Tilix
    CFunc.dnfinstall("tilix tilix-nautilus")
    if not args.bare:
        CFunc.dnfinstall("gstreamer1-libav gstreamer1-vaapi gstreamer1-plugins-ugly gstreamer1-plugins-bad-freeworld gstreamer1-plugins-bad-nonfree")
        CFunc.dnfinstall("youtube-dl ffmpeg vlc smplayer mpv")
        CFunc.dnfinstall("audacious audacious-plugins")
        # Editors
        CFunc.dnfinstall("code")
        # Syncthing
        CFunc.dnfinstall("syncthing")

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
    CFunc.dnfinstall("@workstation-product @gnome-desktop")
    subprocess.run("systemctl enable -f gdm", shell=True)
    # Some Gnome Extensions
    CFunc.dnfinstall("gnome-terminal-nautilus gnome-tweak-tool dconf-editor")
    CFunc.dnfinstall("gnome-shell-extension-gpaste gnome-shell-extension-media-player-indicator gnome-shell-extension-topicons-plus gnome-shell-extension-dash-to-dock")
    # Compile schemas if needed.
    subprocess.run("glib-compile-schemas /usr/share/gnome-shell/extensions/mediaplayer@patapon.info/schemas/", shell=True)
    subprocess.run("{0}/DExtGnome.py -v".format(SCRIPTDIR), shell=True)
    # Adapta
    CFunc.dnfinstall("gnome-shell-theme-adapta adapta-gtk-theme-metacity adapta-gtk-theme-gtk2 adapta-gtk-theme-gtk3")
elif args.desktop == "kde":
    # KDE
    CFunc.dnfinstall("@kde-desktop-environment")
    CFunc.dnfinstall("ark latte-dock")
    subprocess.run("systemctl enable -f sddm", shell=True)
elif args.desktop == "mate":
    # MATE
    CFunc.dnfinstall("@mate-desktop @mate-applications")
    subprocess.run("systemctl enable -f lightdm", shell=True)
    # Applications
    CFunc.dnfinstall("dconf-editor")
elif args.desktop == "xfce":
    CFunc.dnfinstall("@xfce-desktop-environment")
elif args.desktop == "lxqt":
    CFunc.dnfinstall("@lxqt-desktop-environment")

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
CFunc.AddUserAllGroups()

# Edit sudoers to add dnf.
if os.path.isdir('/etc/sudoers.d'):
    CUSTOMSUDOERSPATH = "/etc/sudoers.d/pkmgt"
    print("Writing {0}".format(CUSTOMSUDOERSPATH))
    with open(CUSTOMSUDOERSPATH, 'w') as sudoers_writefile:
        sudoers_writefile.write("""%wheel ALL=(ALL) ALL
{0} ALL=(ALL) NOPASSWD: {1}
""".format(USERNAMEVAR, shutil.which("dnf")))
    os.chmod(CUSTOMSUDOERSPATH, 0o440)
    status = subprocess.run('visudo -c', shell=True)
    if status.returncode is not 0:
        print("Visudo status not 0, removing sudoers file.")
        os.remove(CUSTOMSUDOERSPATH)

# Hdparm
CFunc.dnfinstall("smartmontools hdparm")

if not args.bare and not args.nogui:
    # Install snapd
    CFunc.dnfinstall("snapd")
    if not os.path.islink("/snap"):
        os.symlink("/var/lib/snapd/snap", "/snap", target_is_directory=True)

    # Flatpak setup
    CFunc.aptinstall("flatpak xdg-desktop-portal")
    CFunc.flatpak_addremote("flathub", "https://flathub.org/repo/flathub.flatpakrepo")



# Disable Selinux
# To get selinux status: sestatus, getenforce
# To enable or disable selinux temporarily: setenforce 1 (to enable), setenforce 0 (to disable)
subprocess.run("sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config /etc/sysconfig/selinux", shell=True)

# Disable the firewall
subprocess.run("systemctl mask firewalld", shell=True)

# Extra scripts
if args.allextra is True:
    subprocess.run("{0}/Csdtimers.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CShellConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CCSClone.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CVMGeneral.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Cxdgdirs.sh".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True)
    subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

print("\nScript End")
