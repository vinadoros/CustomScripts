#!/usr/bin/env python3

# Python includes.
import argparse
import grp
import os
import pwd
import shutil
import subprocess
import sys

print("Running {0}".format(__file__))

# Get arguments
parser = argparse.ArgumentParser(description='Install OpenSUSE Software.')
parser.add_argument("-d", "--desktop", dest="desktop", type=int, help='Desktop Environment', default="0")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:",args.desktop)

# Exit if not root.
if not os.geteuid() == 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
if os.getenv("SUDO_USER") != None and os.getenv("SUDO_USER") != "root":
    USERNAMEVAR=os.getenv("SUDO_USER")
elif os.getenv("USER") != "root":
    USERNAMEVAR=os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR=pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP=grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
USERHOME=os.path.expanduser("~")
print("Username is:",USERNAMEVAR)
print("Group Name is:",USERGROUP)

# Get VM State
# Detect QEMU
with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
    DATA=VAR.read().replace('\n', '')
    if "QEMU" in DATA:
        QEMUGUEST=True
    else:
        QEMUGUEST=False
# Detect Virtualbox
with open('/sys/devices/virtual/dmi/id/product_name', 'r') as VAR:
    DATA=VAR.read().replace('\n', '')
    if "VirtualBox" in DATA:
        VBOXGUEST=True
    else:
     	VBOXGUEST=False
# Detect VMWare
with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
    DATA=VAR.read().replace('\n', '')
    if "VMware" in DATA:
        VMWGUEST=True
    else:
     	VMWGUEST=False

# Set up OpenSUSE Repos
REPOSCRIPT="""#!/bin/bash

# Remove existing CD repo
source /etc/os-release
if ls /etc/zypp/repos.d/openSUSE-$VERSION_ID*.repo; then
    rm /etc/zypp/repos.d/openSUSE-$VERSION_ID*.repo
fi
# Add tumbleweed online repos
zypper ar -f http://download.opensuse.org/tumbleweed/repo/oss/ repo-oss
zypper ar -f http://download.opensuse.org/update/tumbleweed/ repo-update
# Add non-oss tumbleweed repo
zypper ar -f http://download.opensuse.org/tumbleweed/repo/non-oss/ repo-non-oss

# Packman
zypper ar -f -n packman http://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/ packman

# Adobe Flash
# https://en.opensuse.org/Adobe_Flash_Player
zypper ar --check --refresh http://linuxdownload.adobe.com/linux/x86_64/ adobe
rpm -ivh http://linuxdownload.adobe.com/adobe-release/adobe-release-x86_64-1.0-1.noarch.rpm
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-adobe-linux

# Numix repo
zypper ar -f http://download.opensuse.org/repositories/home:/kkirill/openSUSE_Factory/ "kkirill's Home Project"

# Terminix repo
zypper ar -f http://download.opensuse.org/repositories/devel:/languages:/D/openSUSE_Tumbleweed/ "devel:languages:D"

# Import all gpg keys
zypper --non-interactive --gpg-auto-import-keys refresh

"""
subprocess.run(REPOSCRIPT, shell=True)

# Install Fedora Software
SOFTWARESCRIPT="""
# Add normal user to all reasonable groups
LISTOFGROUPS="$(cut -d: -f1 /etc/group)"
LISTOFGROUPS=${{LISTOFGROUPS//root}}
LISTOFGROUPS=${{LISTOFGROUPS//users}}
LISTOFGROUPS=${{LISTOFGROUPS//nobody}}
LISTOFGROUPS=${{LISTOFGROUPS//nogroup}}
echo Groups to Add: $LISTOFGROUPS
for grp in $LISTOFGROUPS; do
    usermod -aG $grp {0}
done

# Install cli tools
zypper install -y fish nano tmux iotop rsync p7zip zip unzip xdg-utils xdg-user-dirs

# Management tools
zypper install -y gparted leafpad

# Install browsers
zypper install -y chromium MozillaFirefox freshplayerplugin
# Adobe Flash
zypper in -y flash-plugin flash-player-ppapi

# Samba
zypper install -y samba samba-client
systemctl enable smb

# NTP configuration
systemctl disable ntpd
systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1

# Cups
zypper install -y cups-pdf

# Wine
zypper install -y wine wine-32bit PlayOnLinux

# Libreoffice
zypper install -l -y libreoffice

# Multimedia
zypper install -l -y pavucontrol paprefs smplayer gstreamer-fluendo-mp3 audacious
# Fix issue with paprefs. Need to file bug at some point...
ln -sf /usr/lib64/pulse-10.0 /usr/lib64/pulse-9.0

# terminator
# zypper install -y typelib-1_0-Vte-2.91 terminator
# Terminix
zypper install -y terminix

# Numix Circle icon theme
zypper install -y numix-icon-theme-circle

# Fonts
zypper in -yl noto-sans-fonts ubuntu-fonts liberation-fonts

# VNC and synergy
zypper install -y xorg-x11-Xvnc tigervnc synergy qsynergy

# run-parts and cron
zypper in -yl perl cron make
[ -d /tmp/run-parts ] && rm -rf /tmp/run-parts
git clone https://github.com/wolfbox/run-parts /tmp/run-parts
cd /tmp/run-parts
make
mkdir -p /usr/local/share/man/man1
make install
[ -d /tmp/run-parts ] && rm -rf /tmp/run-parts
systemctl disable cron

# Change to NetworkManager
systemctl disable wicked
systemctl enable NetworkManager
""".format(USERNAMEVAR)
# Install software for VMs
if QEMUGUEST is True:
    SOFTWARESCRIPT+="""
# Guest Agent
zypper install -y spice-vdagent qemu-guest-agent
"""
if VBOXGUEST is True:
    SOFTWARESCRIPT+="""
"""
if VMWGUEST is True:
    SOFTWARESCRIPT+="""
# VM tools
zypper install -y open-vm-tools open-vm-tools-desktop
"""
subprocess.run(SOFTWARESCRIPT, shell=True)

# Install Desktop Software
DESKTOPSCRIPT=""""""
if args.desktop is 1:
    DESKTOPSCRIPT+="""
# Gnome
zypper install -l -y -t pattern gnome_admin gnome_basis gnome_basis_opt gnome_imaging gnome_utilities gnome_laptop gnome_yast sw_management_gnome
zypper install -l -y eog gedit gedit-plugins dconf-editor caribou evince gnome-disk-utility gnome-logs gnome-system-monitor nautilus-evince mousetweaks
zypper install -y gdm
zypper install -y gnome-shell-extension-gpaste gnome-shell-classic
# Change display manager to gdm
sed -i 's/DISPLAYMANAGER=.*$/DISPLAYMANAGER="gdm"/g' /etc/sysconfig/displaymanager
"""
elif args.desktop is 2:
    DESKTOPSCRIPT+="""
# KDE
if rpm -iq patterns-openSUSE-x11_yast; then
    zypper remove -y patterns-openSUSE-x11_yast
fi
zypper install -l -y -t pattern kde kde_plasma
zypper install -l -y sddm
# Change display manager to sddm
sed -i 's/DISPLAYMANAGER=.*$/DISPLAYMANAGER="sddm"/g' /etc/sysconfig/displaymanager
"""
elif args.desktop is 3:
    DESKTOPSCRIPT+="""
# MATE
zypper install -l -y -t pattern mate_basis mate_admin mate_utilities
# Applications
zypper install -l -y dconf-editor atril eom mate-search-tool mate-system-monitor caja-extension-open-terminal caja-extension-atril caja-extension-gksu mate-tweak
# Display Manager
zypper install -y lightdm lightdm-gtk-greeter
# Change display manager to lightdm
sed -i 's/DISPLAYMANAGER=.*$/DISPLAYMANAGER="lightdm"/g' /etc/sysconfig/displaymanager
"""

DESKTOPSCRIPT+="""
systemctl set-default graphical.target

# Delete defaults in sudoers.
if grep -iq $'^Defaults secure_path' /etc/sudoers; then
    sed -e 's/^Defaults env_reset$/Defaults !env_reset/g' -i /etc/sudoers
	sed -i $'/^Defaults mail_badpass/ s/^#*/#/' /etc/sudoers
	sed -i $'/^Defaults secure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c
"""
subprocess.run(DESKTOPSCRIPT, shell=True)

# Edit sudoers to add zypper.
if os.path.isdir('/etc/sudoers.d'):
    CUSTOMSUDOERSPATH="/etc/sudoers.d/pkmgt"
    print("Writing {0}".format(CUSTOMSUDOERSPATH))
    with open(CUSTOMSUDOERSPATH, 'w') as sudoers_writefile:
        sudoers_writefile.write("""%wheel ALL=(ALL) ALL
{0} ALL=(ALL) NOPASSWD: {1}
""".format(USERNAMEVAR, shutil.which("zypper")))
    os.chmod(CUSTOMSUDOERSPATH, 0o440)
    status = subprocess.run('visudo -c', shell=True)
    if status.returncode is not 0:
        print("Visudo status not 0, removing sudoers file.")
        os.remove(CUSTOMSUDOERSPATH)

# Run only on real machine
if QEMUGUEST is not True and VBOXGUEST is not True and VMWGUEST is not True:
    # Copy synergy to global startup folder
    shutil.copy2("/usr/share/applications/qsynergy.desktop", "/etc/xdg/autostart/qsynergy.desktop")

# Add to cron
ZYPPERCRONSCRIPT="/etc/cron.daily/updclnscript"
if os.path.isdir('/etc/cron.daily'):
    print("Writing {0}".format(ZYPPERCRONSCRIPT))
    with open(ZYPPERCRONSCRIPT, 'w') as zyppercron_writefile:
        zyppercron_writefile.write("""#!/bin/bash
# Update the system
# zypper up -yl --no-recommends
# Clean kernels
purge-kernels
""")
    os.chmod(ZYPPERCRONSCRIPT, 0o777)
