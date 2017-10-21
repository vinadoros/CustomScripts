#!/usr/bin/env python3
"""Install Ubuntu Software"""

# Python includes.
import argparse
import grp
import os
import platform
import pwd
import shutil
import subprocess
import sys

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get arguments
parser = argparse.ArgumentParser(description='Install Ubuntu Software.')
parser.add_argument("-d", "--desktop", dest="desktop", type=int, help='Desktop Environment', default="0")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)

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

# Select ubuntu url
UBUNTUURL = "http://archive.ubuntu.com/ubuntu/"
UBUNTUARMURL = "http://ports.ubuntu.com/ubuntu-ports/"
if MACHINEARCH is "armhf":
    URL = UBUNTUARMURL
else:
    URL = UBUNTUURL
print("Ubuntu URL is "+URL)

# Get VM State
# Detect QEMU
with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
    DATA = VAR.read().replace('\n', '')
    QEMUGUEST = bool("QEMU" in DATA)
# Detect Virtualbox
with open('/sys/devices/virtual/dmi/id/product_name', 'r') as VAR:
    DATA = VAR.read().replace('\n', '')
    VBOXGUEST = bool("VirtualBox" in DATA)
# Detect VMWare
with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
    DATA = VAR.read().replace('\n', '')
    VMWGUEST = bool("VMware" in DATA)


### Functions ###
def update():
    """Update apt sources"""
    subprocess.run("apt-get update", shell=True)
def distupg():
    """Upgrade/Dist-Upgrade system"""
    update()
    subprocess.run("apt-get upgrade -y", shell=True)
    subprocess.run("apt-get dist-upgrade -y", shell=True)
def install(apps):
    """Install application(s)"""
    print("\nInstalling {0}".format(apps))
    subprocess.run("apt-get install -y {0}".format(apps), shell=True)
def subpout(cmd):
    """Get output from subprocess"""
    output = subprocess.run("{0}".format(cmd), shell=True, stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return output
def ppa(ppasource):
    """Add a ppa"""
    subprocess.run("add-apt-repository -y '{0}'".format(ppasource), shell=True)
    update()
    subprocess.run("/usr/local/bin/keymissing", shell=True)


# Keymissing script
with open('/usr/local/bin/keymissing', 'w') as writefile:
    writefile.write('''#!/bin/bash
APTLOG=/tmp/aptlog
sudo apt-get update 2> $APTLOG
if [ -f $APTLOG ]
then
	for key in $(grep "NO_PUBKEY" $APTLOG |sed "s/.*NO_PUBKEY //"); do
			echo -e "\\nProcessing key: $key"
			sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $key
			sudo apt-get update
	done
	rm $APTLOG
fi''')
os.chmod('/usr/local/bin/keymissing', 0o777)


# Get Ubuntu Release
update()
install("lsb-release software-properties-common apt-transport-https")
debrelease = subpout("lsb_release -sc")
print("Release is {0}.".format(debrelease))

### Set up Ubuntu Repos ###
# Main, Restricted, universe, and multiverse for Ubuntu.
subprocess.run("""
add-apt-repository main
add-apt-repository restricted
add-apt-repository universe
add-apt-repository multiverse
""", shell=True)

# Add updates, security, and backports.
with open('/etc/apt/sources.list', 'r') as VAR:
    DATA = VAR.read()
    # Updates
    if not "{0}-updates main".format(debrelease) in DATA:
        print("\nAdding updates to sources.list")
        subprocess.run('add-apt-repository "deb {URL} {DEBRELEASE}-updates main restricted universe multiverse"'.format(URL=URL, DEBRELEASE=debrelease), shell=True)
    # Security
    if not "{0}-security main".format(debrelease) in DATA:
        print("\nAdding security to sources.list")
        subprocess.run('add-apt-repository "deb {URL} {DEBRELEASE}-security main restricted universe multiverse"'.format(URL=URL, DEBRELEASE=debrelease), shell=True)
    # Backports
    if not "{0}-backports main".format(debrelease) in DATA:
        print("\nAdding backports to sources.list")
        subprocess.run('add-apt-repository "deb {URL} {DEBRELEASE}-backports main restricted universe multiverse"'.format(URL=URL, DEBRELEASE=debrelease), shell=True)

# Comment out lines containing httpredir.
subprocess.run("sed -i '/httpredir/ s/^#*/#/' /etc/apt/sources.list", shell=True)

# Add timeouts for repository connections
with open('/etc/apt/apt.conf.d/99timeout', 'w') as writefile:
    writefile.write('''Acquire::http::Timeout "5";
Acquire::https::Timeout "5";
Acquire::ftp::Timeout "5";''')

# Update and upgrade with new base repositories
update()
distupg()

### Software ###

install("sudo")
subprocess.run("usermod -aG sudo {0}".format(USERNAMEVAR), shell=True)
subprocess.run("""
# Delete defaults in sudoers for Debian.
if grep -iq '^Defaults\tenv_reset' /etc/sudoers; then
	sed -i '/^Defaults\tenv_reset/ s/^#*/#/' /etc/sudoers
	# Consider changing above line to below line in future (as in Opensuse)
	# sed -e 's/^Defaults env_reset$/Defaults !env_reset/g' -i /etc/sudoers
	sed -i '/^Defaults\tmail_badpass/ s/^#*/#/' /etc/sudoers
	sed -i '/^Defaults\tsecure_path/ s/^#*/#/' /etc/sudoers
fi
visudo -c""", shell=True)

install("ssh tmux")
# Fish Shell
# Install ppa only if lts
if debrelease is "xenial":
    ppa("ppa:fish-shell/release-2")
install("fish")
# Add fish to shells
with open('/etc/shells', 'r') as VAR:
    DATA = VAR.read()
    FISHPATH = shutil.which("fish")
    if not FISHPATH in DATA:
        print("\nAdding fish to /etc/shells")
        subprocess.run('echo "{0}" >> /etc/shells'.format(FISHPATH), shell=True)

# Syncthing
if os.path.isfile("/etc/apt/sources.list.d/syncthing-release.list") is False:
    subprocess.run("wget -qO- https://syncthing.net/release-key.txt | apt-key add -", shell=True)
    # Write syncthing sources list
    with open('/etc/apt/sources.list.d/syncthing-release.list', 'w') as stapt_writefile:
        stapt_writefile.write("deb http://apt.syncthing.net/ syncthing release")
    # Update and install syncthing:
    update()
    install("syncthing syncthing-inotify")

# General GUI software
install("synaptic gdebi gparted xdg-utils leafpad nano p7zip-full p7zip-rar unrar")
install("gnome-disk-utility btrfs-tools f2fs-tools xfsprogs dmraid mdadm")
# Timezone stuff
subprocess.run("dpkg-reconfigure -f noninteractive tzdata", shell=True)
# CLI and system utilities
install("curl rsync less iotop sshfs")
# Needed for systemd user sessions.
install("dbus-user-session")
# Samba
install("samba cifs-utils")
# NTP
subprocess.run("""systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1""", shell=True)
# Avahi
install("avahi-daemon avahi-discover libnss-mdns")
# Cups-pdf
install("printer-driver-cups-pdf")
# Media Playback
install("vlc audacious ffmpeg youtube-dl smplayer")
install("alsa-utils pavucontrol paprefs pulseaudio-module-zeroconf pulseaudio-module-bluetooth swh-plugins")
install("gstreamer1.0-vaapi")
# Wine
install("playonlinux wine64-development wine32-development-preloader")
# For Office 2010
install("winbind")
install("fonts-powerline fonts-noto fonts-roboto")
# Browsers
install("chromium-browser firefox flashplugin-installer pepperflashplugin-nonfree")
# Tilix
ppa("ppa:webupd8team/terminix")
install("tilix")
# Cron
install("cron anacron")
subprocess.run("systemctl disable cron; systemctl disable anacron", shell=True)
# Java
install("default-jre")
# Atom Editor
ppa("ppa:webupd8team/atom")
install("atom")

# Visual Studio Code
subprocess.run("""curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg""", shell=True)
# Install repo
subprocess.run('echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list', shell=True)
update()
install("code")

# Network Manager
install("network-manager network-manager-ssh resolvconf")
subprocess.run("apt-get install -y network-manager-config-connectivity-ubuntu", shell=True, check=False)
subprocess.run("sed -i 's/managed=.*/managed=true/g' /etc/NetworkManager/NetworkManager.conf", shell=True)
# https://askubuntu.com/questions/882806/ethernet-device-not-managed
with open('/etc/NetworkManager/conf.d/10-globally-managed-devices.conf', 'w') as writefile:
    writefile.write("""[keyfile]
unmanaged-devices=none""")
# Ensure DNS resolution is working
subprocess.run("dpkg-reconfigure --frontend=noninteractive resolvconf", shell=True)

# Disable apport if it exists
if os.path.isfile("/etc/default/apport"):
    subprocess.run("sed -i 's/^enabled=.*/enabled=0/g' /etc/default/apport", shell=True)

# Install Desktop Software
if args.desktop is 1:
    print("\n Installing gnome desktop")
    install("ubuntu-desktop ubuntu-session gnome-session")
    install("gnome-clocks")
    install("gnome-shell-extension-mediaplayer gnome-shell-extension-top-icons-plus gnome-shell-extensions-gpaste")
    subprocess.run("{0}/DExtGnome.sh -v".format(SCRIPTDIR), shell=True)
elif args.desktop is 2:
    print("\n Installing kde desktop")
    install("kubuntu-desktop")
elif args.desktop is 3:
    print("\n Installing mate desktop")
    install("ubuntu-mate-core ubuntu-mate-default-settings ubuntu-mate-desktop")
    install("ubuntu-mate-lightdm-theme dconf-cli")
elif args.desktop is 4:
    print("\n Installing xfce desktop")
    install("xubuntu-desktop")

# Numix
ppa("ppa:numix/ppa")
install("numix-icon-theme-circle")

# Emulator ppa
ppa("ppa:random-stuff/ppa")

# Adapta
ppa("ppa:tista/adapta")
install("adapta-gtk-theme")


# Install guest software for VMs
if QEMUGUEST is True:
    install("spice-vdagent qemu-guest-agent")
if VBOXGUEST is True:
    install("virtualbox-guest-utils virtualbox-guest-x11 virtualbox-guest-dkms dkms")
    subprocess.run("gpasswd -a {0} vboxsf".format(USERNAMEVAR), shell=True)
if VMWGUEST is True:
    install("open-vm-tools open-vm-tools-dkms open-vm-tools-desktop")

# Run only on real machine
if QEMUGUEST is not True and VBOXGUEST is not True and VMWGUEST is not True:
    # Install virtualbox
    subprocess.run("""#!/bin/bash
# Virtualbox Host
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add -
add-apt-repository "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib"
apt-get update
apt-get install -y virtualbox-5.2
VBOXVER=$(vboxmanage -v)
VBOXVER2=$(echo $VBOXVER | cut -d 'r' -f 1)
wget -P ~/ http://download.virtualbox.org/virtualbox/$VBOXVER2/Oracle_VM_VirtualBox_Extension_Pack-$VBOXVER2.vbox-extpack
yes | VBoxManage extpack install --replace ~/Oracle_VM_VirtualBox_Extension_Pack-$VBOXVER2.vbox-extpack
rm ~/Oracle_VM_VirtualBox_Extension_Pack-$VBOXVER2.vbox-extpack""", shell=True, check=False)
    # Synergy
    install("synergy")


### Architecture Specific Section ###
if MACHINEARCH is not "armv7l":
    subprocess.run("apt-get install -y --no-install-recommends tlp smartmontools ethtool", shell=True)

# Add normal user to all reasonable groups
GROUPSCRIPT = """
# Get all groups
LISTOFGROUPS="$(cut -d: -f1 /etc/group)"
# Remove some groups
CUTGROUPS=$(sed -e "/^users/d; /^root/d; /^nobody/d; /^nogroup/d; /^$USERGROUP/d" <<< $LISTOFGROUPS)
echo Groups to Add: $CUTGROUPS
for grp in $CUTGROUPS; do
    usermod -aG $grp {0}
done
""".format(USERNAMEVAR)
subprocess.run(GROUPSCRIPT, shell=True)

# Edit sudoers to add apt.
if os.path.isdir('/etc/sudoers.d'):
    CUSTOMSUDOERSPATH = "/etc/sudoers.d/pkmgt"
    print("Writing {0}".format(CUSTOMSUDOERSPATH))
    with open(CUSTOMSUDOERSPATH, 'w') as sudoers_writefile:
        sudoers_writefile.write("{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("apt")))
        sudoers_writefile.write("{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("apt-get")))
    os.chmod(CUSTOMSUDOERSPATH, 0o440)
    status = subprocess.run('visudo -c', shell=True)
    if status.returncode is not 0:
        print("Visudo status not 0, removing sudoers file.")
        os.remove(CUSTOMSUDOERSPATH)
