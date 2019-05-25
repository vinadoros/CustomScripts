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
parser.add_argument("-l", "--lts", help='Configure script to run for an LTS release.', action="store_true")
parser.add_argument("-b", "--bare", help='Configure script to set up a bare-minimum environment.', action="store_true")
parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)
print("LTS Mode:", args.lts)
print("Bare install:", args.bare)
print("No GUI:", args.nogui)

# Exit if not root.
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


### Begin Code ###

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
print("Ubuntu URL is " + URL)

# Get VM State
vmstatus = CFunc.getvmstate()

# Set non-interactive flag
os.environ['DEBIAN_FRONTEND'] = "noninteractive"
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
    sed -e 's/^Defaults\tenv_reset$/Defaults\t!env_reset/g' -i /etc/sudoers
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

# Cli Software
CFunc.aptinstall("ssh tmux btrfs-tools f2fs-tools xfsprogs dmraid mdadm nano p7zip-full p7zip-rar unrar curl rsync less iotop sshfs")
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
# Drivers
CFunc.aptinstall("intel-microcode")

# Non-bare CLI stuff.
if args.bare is False:
    # Zsh/fish
    CFunc.aptinstall("zsh fish")

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
# Set netplan to use Network Manager
if os.path.isfile('/etc/netplan/01-netcfg.yaml'):
    with open('/etc/netplan/01-netcfg.yaml', 'w') as writefile:
        writefile.write("""network:
  version: 2
  renderer: NetworkManager""")


# Due to odd GUI recommends on 19.04 and above, the following packages should be held for other desktop environments. They should be unheld for gnome.
held_pkgs = "gnome-shell gdm3 gnome-session gnome-session-bin ubuntu-session gnome-desktop3-data gnome-control-center cheese"

# Install Desktop Software
if args.desktop == "gnome":
    print("\n Installing gnome desktop")
    CFunc.aptmark(held_pkgs, mark=False)
    CFunc.aptinstall("ubuntu-desktop ubuntu-session gnome-session")
    CFunc.aptinstall("gnome-clocks")
    CFunc.snap_install("gnome-calculator gnome-characters gnome-logs gnome-system-monitor")
    CFunc.aptinstall("gnome-shell-extensions")
    # subprocess.run("{0}/DExtGnome.py -t -v -d".format(SCRIPTDIR), shell=True)
    CFunc.aptinstall("gnome-software-plugin-flatpak")
    # Install gs installer script.
    gs_installer = CFunc.downloadfile("https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer", os.path.join(os.sep, "usr", "local", "bin"), overwrite=True)
    os.chmod(gs_installer[0], 0o777)
    # Install volume extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 858".format(gs_installer[0]))
    # Install topiconsplus extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 1031".format(gs_installer[0]))
    # Install dashtodock extension
    CFunc.run_as_user(USERNAMEVAR, "{0} --yes 307".format(gs_installer[0]))
elif args.desktop == "kde":
    print("\n Installing kde desktop")
    CFunc.aptmark(held_pkgs)
    CFunc.addppa("ppa:kubuntu-ppa/backports")
    CFunc.addppa("ppa:papirus/papirus")
    CFunc.aptinstall("kubuntu-desktop")
elif args.desktop == "neon":
    print("\n Installing kde neon desktop.")
    CFunc.aptmark(held_pkgs)
    subprocess.run("wget -qO - 'http://archive.neon.kde.org/public.key' | apt-key add -", shell=True)
    subprocess.run("apt-add-repository http://archive.neon.kde.org/user", shell=True)
    CFunc.aptupdate()
    CFunc.aptdistupg()
    CFunc.aptinstall("neon-desktop")
    CFunc.aptdistupg()
elif args.desktop == "mate":
    print("\n Installing mate desktop")
    CFunc.aptmark(held_pkgs)
    CFunc.aptinstall("ubuntu-mate-core ubuntu-mate-default-settings ubuntu-mate-desktop")
    CFunc.aptinstall("ubuntu-mate-lightdm-theme")
    # Run MATE Configuration
    subprocess.run("{0}/DExtMate.py -c".format(SCRIPTDIR), shell=True)
elif args.desktop == "xfce":
    print("\n Installing xfce desktop")
    CFunc.aptmark(held_pkgs)
    CFunc.aptinstall("xubuntu-desktop")
elif args.desktop == "budgie":
    print("\n Installing budgie desktop")
    CFunc.aptmark(held_pkgs)
    CFunc.aptinstall("ubuntu-budgie-desktop")
    CFunc.aptinstall("gnome-software-plugin-flatpak")

# Post DE install stuff.
if args.nogui is False and args.bare is False:
    # Numix
    CFunc.addppa("ppa:numix/ppa")
    CFunc.aptinstall("numix-icon-theme-circle")
    # KeepassXC
    CFunc.addppa("ppa:phoerious/keepassxc")
    CFunc.aptinstall("keepassxc")

# GUI Software
if args.nogui is False:
    CFunc.aptinstall("dconf-cli dconf-editor")
    CFunc.aptinstall("synaptic gnome-disk-utility gdebi gparted xdg-utils")
    CFunc.aptinstall("fonts-powerline fonts-noto fonts-roboto")
    if args.lts:
        # MS Fonts (this debian package is a workaround for a download bug, https://askubuntu.com/q/463754)
        msfntkey = CFunc.downloadfile("http://http.us.debian.org/debian/pool/contrib/m/msttcorefonts/ttf-mscorefonts-installer_3.6_all.deb", "/var/tmp")
        CFunc.aptinstall(msfntkey[0])
        if os.path.isfile(msfntkey[0]):
            os.remove(msfntkey[0])
        # Don't upgrade this manually installed package.
        subprocess.run("apt-mark hold ttf-mscorefonts-installer", shell=True)
    else:
        subprocess.run("echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections", shell=True)
        CFunc.aptinstall("ttf-mscorefonts-installer")

# General GUI software
if args.nogui is False and args.bare is False:
    # Cups-pdf
    CFunc.aptinstall("printer-driver-cups-pdf")
    # Media Playback
    CFunc.aptinstall("vlc audacious ffmpeg youtube-dl smplayer")
    CFunc.aptinstall("alsa-utils pavucontrol paprefs pulseaudio-module-zeroconf pulseaudio-module-bluetooth swh-plugins")
    CFunc.aptinstall("gstreamer1.0-vaapi")
    # Wine
    CFunc.aptinstall("playonlinux wine64-development wine32-development")
    # For Office 2010
    CFunc.aptinstall("winbind")
    # Browsers
    CFunc.aptinstall("chromium-browser firefox flashplugin-installer pepperflashplugin-nonfree")
    # Tilix
    if args.lts is True:
        CFunc.addppa("ppa:webupd8team/terminix")
    CFunc.aptinstall("tilix")
    # Flatpak
    CFunc.aptinstall("flatpak")
    CFunc.flatpak_addremote("flathub", "https://flathub.org/repo/flathub.flatpakrepo")
    # Visual Studio Code
    subprocess.run("""curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg""", shell=True)
    # Install repo
    subprocess.run('echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list', shell=True)
    CFunc.aptupdate()
    CFunc.aptinstall("code")


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


subprocess.run("apt-get install -y --no-install-recommends smartmontools", shell=True)

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

# Run these extra scripts even in bare config.
subprocess.run("{0}/CShellConfig.py -f -d".format(SCRIPTDIR), shell=True)
subprocess.run("{0}/Csshconfig.sh".format(SCRIPTDIR), shell=True)
subprocess.run("{0}/CCSClone.py".format(SCRIPTDIR), shell=True)
subprocess.run("{0}/CDisplayManagerConfig.py".format(SCRIPTDIR), shell=True)
subprocess.run("{0}/CVMGeneral.sh".format(SCRIPTDIR), shell=True)
subprocess.run("{0}/Cxdgdirs.py".format(SCRIPTDIR), shell=True)
subprocess.run("{0}/Czram.py".format(SCRIPTDIR), shell=True)
subprocess.run("{0}/CSysConfig.sh".format(SCRIPTDIR), shell=True)

print("\nScript End")
