#!/usr/bin/env python3
"""Install Debian Software"""

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
parser.add_argument("-u", "--unstable", help='Upgrade to unstable.', action="store_true")
parser.add_argument("-b", "--bare", help='Configure script to set up a bare-minimum environment.', action="store_true")
parser.add_argument("-x", "--nogui", help='Configure script to disable GUI.', action="store_true")

# Save arguments.
args = parser.parse_args()
print("Desktop Environment:", args.desktop)
print("Run extra scripts:", args.allextra)
print("Unstable Mode:", args.unstable)
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

# Select debian url
URL = "http://http.us.debian.org/debian"
print("Debian Mirror URL is "+URL)

# Get VM State
vmstatus = CFunc.getvmstate()


### Begin Code ###

# Get Ubuntu Release
CFunc.aptupdate()
CFunc.aptinstall("lsb-release software-properties-common apt-transport-https gnupg")
# Detect OS information
distro, debrelease = CFunc.detectdistro()
print("Distro is {0}.".format(distro))
print("Release is {0}.".format(debrelease))

### Set up Debian Repos ###
# Change to unstable.
if args.unstable:
    debrelease = "sid"
    print("\n Enable unstable repositories.")
    with open('/etc/apt/sources.list', 'w') as writefile:
        writefile.write('deb {0} sid main contrib non-free'.format(URL))
# Main, Contrib, Non-Free for Debian.
subprocess.run("""
add-apt-repository main
add-apt-repository contrib
add-apt-repository non-free
""", shell=True)


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


if not args.bare:
    # Syncthing
    subprocess.run("wget -qO- https://syncthing.net/release-key.txt | apt-key add -", shell=True)
    # Write syncthing sources list
    with open('/etc/apt/sources.list.d/syncthing-release.list', 'w') as stapt_writefile:
        stapt_writefile.write("deb http://apt.syncthing.net/ syncthing release")
    # Update and install syncthing:
    CFunc.aptupdate()
    CFunc.aptinstall("syncthing syncthing-inotify")

    # Debian Multimedia
    # Write sources list
    if args.unstable:
        multimedia_release = "sid"
    else:
        multimedia_release = "testing"
    with open('/etc/apt/sources.list.d/debian-multimedia.list', 'w') as stapt_writefile:
        stapt_writefile.write("deb https://www.deb-multimedia.org {0} main non-free".format(multimedia_release))
    subprocess.run("apt-get update -oAcquire::AllowInsecureRepositories=true; apt-get install -y --allow-unauthenticated deb-multimedia-keyring -oAcquire::AllowInsecureRepositories=true", shell=True)

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
    CFunc.aptinstall("alsa-utils pavucontrol pulseaudio-module-zeroconf pulseaudio-module-bluetooth swh-plugins")
    CFunc.aptinstall("paprefs")
    CFunc.aptinstall("gstreamer1.0-vaapi")
    # Wine
    CFunc.aptinstall("playonlinux wine64 wine32")
    # For Office 2010
    CFunc.aptinstall("winbind")
    CFunc.aptinstall("fonts-powerline fonts-noto fonts-roboto")
    # Browsers
    CFunc.aptinstall("chromium pepperflashplugin-nonfree")
    if args.unstable:
        CFunc.aptinstall("firefox")
    else:
        CFunc.aptinstall("firefox-esr")
    CFunc.aptinstall("browser-plugin-freshplayer-pepperflash")
    # Tilix
    CFunc.aptinstall("tilix")
    # Visual Studio Code
    subprocess.run("""curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg""", shell=True)
    # Install repo
    subprocess.run('echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list', shell=True)
    CFunc.aptupdate()
    CFunc.aptinstall("code")

# Network Manager
CFunc.aptinstall("network-manager network-manager-ssh resolvconf")
# Ensure DNS resolution is working
subprocess.run("dpkg-reconfigure --frontend=noninteractive resolvconf", shell=True)

# Disable apport if it exists
if os.path.isfile("/etc/default/apport"):
    subprocess.run("sed -i 's/^enabled=.*/enabled=0/g' /etc/default/apport", shell=True)

# Install Desktop Software
if args.desktop == "gnome":
    print("\n Installing gnome desktop")
    CFunc.aptinstall("task-gnome-desktop")
    CFunc.aptinstall("gnome-clocks")
    CFunc.aptinstall("gnome-shell-extensions gnome-shell-extension-dashtodock gnome-shell-extension-mediaplayer gnome-shell-extension-top-icons-plus gnome-shell-extensions-gpaste")
    subprocess.run("{0}/DExtGnome.py -v".format(SCRIPTDIR), shell=True)
elif args.desktop == "mate":
    print("\n Installing mate desktop")
    CFunc.aptinstall("task-mate-desktop mate-tweak dconf-cli")
elif args.desktop == "xfce":
    print("\n Installing xfce desktop")
    CFunc.aptinstall("task-xfce-desktop")
elif args.desktop == "lxqt":
    print("\n INstalling lxqt desktop")
    CFunc.aptinstall("task-lxqt-desktop")

# Post DE install stuff.
if args.nogui is False and args.bare is False:
    # Numix Circle Icons
    iconfolder = os.path.join("/", "usr", "local", "share", "icons")
    os.makedirs(iconfolder, exist_ok=True)
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme-circle"), ignore_errors=True)
    shutil.rmtree(os.path.join(iconfolder, "Numix-Circle"), ignore_errors=True)
    subprocess.run("git clone https://github.com/numixproject/numix-icon-theme-circle.git {0}".format(os.path.join(iconfolder, "numix-icon-theme-circle")), shell=True)
    shutil.move(os.path.join(iconfolder, "numix-icon-theme-circle", "Numix-Circle"), iconfolder)
    shutil.rmtree(os.path.join(iconfolder, "numix-icon-theme-circle"), ignore_errors=True)
    subprocess.run("gtk-update-icon-cache {0}".format(os.path.join(iconfolder, "/Numix-Circle")), shell=True)


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


# subprocess.run("apt-get install -y --no-install-recommends powertop smartmontools", shell=True)
# # Write and enable powertop systemd-unit file.
# Powertop_SystemdServiceText = '''[Unit]
# Description=Powertop tunings
#
# [Service]
# ExecStart={0} --auto-tune
# RemainAfterExit=true
#
# [Install]
# WantedBy=multi-user.target'''.format(shutil.which("powertop"))
# CFunc.systemd_createsystemunit("powertop.service", Powertop_SystemdServiceText, True)

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
