#!/usr/bin/env python3
"""Install Ubuntu Software"""

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
parser = argparse.ArgumentParser(description='Install Ubuntu Software.')
parser.add_argument("-d", "--desktop", help='Desktop Environment (i.e. gnome, kde, mate, etc)')
parser.add_argument("-a", "--allextra", help='Run Extra Scripts', action="store_true")
parser.add_argument("-l", "--lts", help='Configure script to run for an LTS release.', action="store_true")
parser.add_argument("-b", "--bare", help='Configure script to set up a bare-minimum environment.', action="store_true")
parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)
print("Run extra scripts:", args.allextra)
print("LTS Mode:", args.bare)
print("Bare install:", args.bare)
print("No GUI:", args.nogui)

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


# Check if root password is set.
rootacctstatus = CFunc.subpout("passwd -S root | awk '{{print $2}}'")
if "P" not in rootacctstatus:
    print("Please set the root password.")
    subprocess.run("passwd root", shell=True)
    print("Please rerun this script now that the root account is unlocked.")
    sys.exit(1)

# Select ubuntu url
UBUNTUURL = "http://archive.ubuntu.com/ubuntu/"
UBUNTUARMURL = "http://ports.ubuntu.com/ubuntu-ports/"
if MACHINEARCH == "armhf":
    URL = UBUNTUARMURL
else:
    URL = UBUNTUURL
print("Ubuntu URL is "+URL)

# Get VM State
vmstatus = CFunc.getvmstate()

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


### Begin Code ###

# Get Ubuntu Release
CFunc.aptupdate()
CFunc.aptinstall("lsb-release software-properties-common apt-transport-https")
# Detect OS information
distro, debrelease = CFunc.detectdistro()
print("Distro is {0}.".format(distro))
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
CFunc.aptupdate()
CFunc.aptdistupg()

### Software ###

CFunc.aptinstall("sudo")
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

# Syncthing
if not args.bare:
    subprocess.run("wget -qO- https://syncthing.net/release-key.txt | apt-key add -", shell=True)
    # Write syncthing sources list
    with open('/etc/apt/sources.list.d/syncthing-release.list', 'w') as stapt_writefile:
        stapt_writefile.write("deb http://apt.syncthing.net/ syncthing release")
    # Update and install syncthing:
    CFunc.aptupdate()
    CFunc.aptinstall("syncthing syncthing-inotify")

# Fish Shell, install ppa only if lts
if args.lts is True:
    CFunc.addppa("ppa:fish-shell/release-2")
# Cli Software
CFunc.aptinstall("ssh tmux fish btrfs-tools f2fs-tools xfsprogs dmraid mdadm nano p7zip-full p7zip-rar unrar curl rsync less iotop sshfs")
# Add fish to shells
with open('/etc/shells', 'r') as VAR:
    DATA = VAR.read()
    FISHPATH = shutil.which("fish")
    if not FISHPATH in DATA:
        print("\nAdding fish to /etc/shells")
        subprocess.run('echo "{0}" >> /etc/shells'.format(FISHPATH), shell=True)
# Timezone stuff
subprocess.run("dpkg-reconfigure -f noninteractive tzdata", shell=True)
# Needed for systemd user sessions.
CFunc.aptinstall("dbus-user-session")
# Samba
CFunc.aptinstall("samba cifs-utils")
# NTP
subprocess.run("""systemctl enable systemd-timesyncd
timedatectl set-local-rtc false
timedatectl set-ntp 1""", shell=True)
# Avahi
CFunc.aptinstall("avahi-daemon avahi-discover libnss-mdns")
# Java
CFunc.aptinstall("default-jre")

# Non-bare CLI stuff.
if args.bare is False:
    # Cron
    CFunc.aptinstall("cron anacron")
    subprocess.run("systemctl disable cron; systemctl disable anacron", shell=True)

# General GUI software
if args.nogui is False and args.bare is False:
    CFunc.aptinstall("synaptic gnome-disk-utility gdebi gparted xdg-utils leafpad")
    # Cups-pdf
    CFunc.aptinstall("printer-driver-cups-pdf")
    # Media Playback
    CFunc.aptinstall("vlc audacious ffmpeg youtube-dl smplayer")
    CFunc.aptinstall("alsa-utils pavucontrol paprefs pulseaudio-module-zeroconf pulseaudio-module-bluetooth swh-plugins")
    CFunc.aptinstall("gstreamer1.0-vaapi")
    # Wine
    CFunc.aptinstall("playonlinux wine64-development wine32-development-preloader")
    # For Office 2010
    CFunc.aptinstall("winbind")
    CFunc.aptinstall("fonts-powerline fonts-noto fonts-roboto")
    # Browsers
    CFunc.aptinstall("chromium-browser firefox flashplugin-installer pepperflashplugin-nonfree")
    # Tilix
    CFunc.addppa("ppa:webupd8team/terminix")
    CFunc.aptinstall("tilix")
    # Atom Editor
    CFunc.addppa("ppa:webupd8team/atom")
    CFunc.aptinstall("atom")
    # Visual Studio Code
    subprocess.run("""curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg""", shell=True)
    # Install repo
    subprocess.run('echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list', shell=True)
    CFunc.aptupdate()
    CFunc.aptinstall("code")

# Network Manager
CFunc.aptinstall("network-manager network-manager-ssh resolvconf")
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
if args.desktop == "gnome":
    print("\n Installing gnome desktop")
    CFunc.aptinstall("ubuntu-desktop ubuntu-session gnome-session")
    CFunc.aptinstall("gnome-clocks")
    # Remove ubuntu dock in order to install dashtodock
    subprocess.run("apt-get remove -y gnome-shell-extension-ubuntu-dock", shell=True, check=False)
    CFunc.aptinstall("gnome-shell-extensions gnome-shell-extension-dashtodock gnome-shell-extension-mediaplayer gnome-shell-extension-top-icons-plus gnome-shell-extensions-gpaste")
    subprocess.run("{0}/DExtGnome.sh -v".format(SCRIPTDIR), shell=True)
elif args.desktop == "kde":
    print("\n Installing kde desktop")
    CFunc.aptinstall("kubuntu-desktop")
elif args.desktop == "mate":
    print("\n Installing mate desktop")
    CFunc.aptinstall("ubuntu-mate-core ubuntu-mate-default-settings ubuntu-mate-desktop")
    CFunc.aptinstall("ubuntu-mate-lightdm-theme dconf-cli")
elif args.desktop == "xfce":
    print("\n Installing xfce desktop")
    CFunc.aptinstall("xubuntu-desktop")

# Post DE install stuff.
if not args.nogui or not args.bare:
    # Numix
    CFunc.addppa("ppa:numix/ppa")
    CFunc.aptinstall("numix-icon-theme-circle")
    # Adapta
    CFunc.addppa("ppa:tista/adapta")
    CFunc.aptinstall("adapta-gtk-theme")


# Install guest software for VMs
if vmstatus == "kvm":
    CFunc.aptinstall("spice-vdagent qemu-guest-agent")
if vmstatus == "vbox":
    CFunc.aptinstall("virtualbox-guest-utils virtualbox-guest-dkms dkms")
    if not args.nogui:
        CFunc.aptinstall("virtualbox-guest-x11")
    subprocess.run("gpasswd -a {0} vboxsf".format(USERNAMEVAR), shell=True)
    subprocess.run("systemctl enable virtualbox-guest-utils", shell=True)
if vmstatus == "vmware":
    CFunc.aptinstall("open-vm-tools open-vm-tools-dkms")
    if not args.nogui:
        CFunc.aptinstall("open-vm-tools-desktop")


subprocess.run("apt-get install -y --no-install-recommends powertop smartmontools", shell=True)
# Write and enable powertop systemd-unit file.
Powertop_SystemdServiceText = '''[Unit]
Description=Powertop tunings

[Service]
ExecStart={0} --auto-tune
RemainAfterExit=true

[Install]
WantedBy=multi-user.target'''.format(shutil.which("powertop"))
CFunc.systemd_createsystemunit("powertop.service", Powertop_SystemdServiceText, True)

if args.bare is False:
    # Add normal user to all reasonable groups
    CFunc.AddUserAllGroups()

    # Edit sudoers to add apt.
    if os.path.isdir('/etc/sudoers.d'):
        CUSTOMSUDOERSPATH = "/etc/sudoers.d/pkmgt"
        print("Writing {0}".format(CUSTOMSUDOERSPATH))
        with open(CUSTOMSUDOERSPATH, 'w') as sudoers_writefile:
            sudoers_writefile.write("{0} ALL=(ALL) NOPASSWD: {1}\n{0} ALL=(ALL) NOPASSWD: {2}\n".format(USERNAMEVAR, shutil.which("apt"), shutil.which("apt-get")))
        os.chmod(CUSTOMSUDOERSPATH, 0o440)
        status = subprocess.run('visudo -c', shell=True)
        if status.returncode is not 0:
            print("Visudo status not 0, removing sudoers file.")
            os.remove(CUSTOMSUDOERSPATH)

    # Extra scripts
    if args.allextra is True:
        subprocess.run("{0}/Csdtimers.sh".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/CBashFish.py".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/CCSClone.sh".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/CDisplayManagerConfig.sh".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/CVMGeneral.sh".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/Cxdgdirs.sh".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True)
        subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

print("\nScript End")
