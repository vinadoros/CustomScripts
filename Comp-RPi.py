#!/usr/bin/env python3

# Python includes.
import argparse
import grp
import os
import platform
import pwd
import shutil
import stat
import subprocess
import sys
import urllib.request

# OmxPlayer from http://omxplayer.sconde.net/
OMXURL = "http://omxplayer.sconde.net/builds/omxplayer_0.3.7~git20170130~62fb580_armhf.deb"
# rpi-update from https://github.com/Hexxeh/rpi-update
RPIUPDATEURL = "https://raw.githubusercontent.com/Hexxeh/rpi-update/master/rpi-update"

# Folder of this script
SCRIPTDIR = sys.path[0]

print("Running {0}".format(__file__))
print("This script is for use only on Ubuntu.")

# Get arguments
parser = argparse.ArgumentParser(description='Install Raspberry Pi stuff.')
parser.add_argument("-c", "--cliutils", help='Install command line utilities', action="store_true")
parser.add_argument("-d", "--docker", help='Install docker', action="store_true")
parser.add_argument("-e", "--desktopomx", help='Install desktop omx scripts', action="store_true")
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-o", "--omxdeb", help='Install OMXPlayer.', action="store_true")
parser.add_argument("-p", "--ppa", help='Install RPi optional ppa and libraspberrypi-dev.', action="store_true")
parser.add_argument("-s", "--scripts", help='Run CustomScripts in this folder.', action="store_true")
parser.add_argument("-u", "--upscript", help='Install rpi-update and run it.', action="store_true")

# Save arguments.
args = parser.parse_args()

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

# Print detected options
print(args)

if args.noprompt is False:
    input("Press Enter to continue.")

# cliutils section
if args.cliutils is True:
    print("Installing command line utilities.")
    subprocess.run("apt-get update; apt-get install -y avahi-daemon wget curl ca-certificates build-essential", shell=True)
    groupscript = """
    # Add normal user to all reasonable groups
    # Get all groups
    LISTOFGROUPS="$(cut -d: -f1 /etc/group)"
    # Remove some groups
    CUTGROUPS=$(sed -e "/^users/d; /^root/d; /^nobody/d; /^nogroup/d; /^{1}/d" <<< $LISTOFGROUPS)
    echo Groups to Add: $CUTGROUPS
    for grp in $CUTGROUPS; do
        usermod -aG $grp {0}
    done
    """.format(USERNAMEVAR, USERGROUP)
    subprocess.run(groupscript, shell=True)
    # Disable pulseaudio suspend-on-idle
    if os.path.isfile("/etc/pulse/system.pa") is True:
        subprocess.run("sed -i '/load-module module-suspend-on-idle/ s/^#*/#/' /etc/pulse/system.pa", shell=True)

if args.scripts is True:
    print("Running extra scripts for Pi.")
    subprocess.run("""
    apt-get update
    apt-get install -y fish
    {0}/Comp-BashFish.py
    {0}/Comp-sdtimers.sh
    systemctl disable cron
    {0}/Comp-zram.py -c 1
    {0}/Comp-sshconfig.sh
    {0}/Comp-CSClone.sh
    """.format(SCRIPTDIR), shell=True)

# upscript section
if args.upscript is True:
    print("Installing rpi-update script.")
    localpiupbinary = "/usr/local/bin/rpi-update"
    urllib.request.urlretrieve(RPIUPDATEURL, localpiupbinary)
    os.chmod(localpiupbinary, 0o777)
    print("Adding and running auto-update for Pi.")
    aptautoupdate_script = """#!/bin/bash
apt-get update
apt-get upgrade -y
apt-get dist-upgrade -y
if [ -f {0} ]; then
    SKIP_WARNING=1 PRUNE_MODULES=1 {0}
fi
    """.format(localpiupbinary)
    cronfolder = "/etc/cron.daily"
    aptautoupdate_file = cronfolder + "/aptautoupdate"
    if os.path.isdir(cronfolder) is True:
        print("Writing {0}".format(aptautoupdate_file))
        with open(aptautoupdate_file, 'w') as aptautoupdate_file_write:
            aptautoupdate_file_write.write(aptautoupdate_script)
        os.chmod(aptautoupdate_file, 0o777)
        # Remove the boot firmware version to refresh all boot and library files.
        if os.path.isfile("/boot/.firmware_revision") is True:
            print("Removing /boot/.firmware_revision")
            os.remove("/boot/.firmware_revision")
        print("Running {0}".format(aptautoupdate_file))
        subprocess.run(aptautoupdate_file, shell=True)
        # Remove all backup folders if they exist.
        if os.path.isdir("/boot.bak") is True:
            print("Removing /boot.bak")
            shutil.rmtree("/boot.bak")
        if os.path.isdir("/lib/modules.bak") is True:
            print("Removing /lib/modules.bak")
            shutil.rmtree("/lib/modules.bak")
    else:
        print(cronfolder, "does not exist. Please install a cron.")

# docker section
if args.docker is True:
    print("Installing Docker.")
    subprocess.run("""
    apt-get update
    apt-get install -y software-properties-common
    add-apt-repository "deb [arch=armhf] https://apt.dockerproject.org/repo raspbian-jessie main"
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    apt-get update
    apt-get install -y docker-engine
    usermod -aG docker {0}
    """.format(USERNAMEVAR), shell=True)

# omxdeb section
if args.omxdeb is True:
    print("Installing omxplayer.")
    tempfolder = "/var/tmp"
    omxdeb_file = tempfolder + "/omxplayer.deb"
    urllib.request.urlretrieve(OMXURL, omxdeb_file)
    if os.path.isfile(omxdeb_file) is True:
        subprocess.run("apt-get install -y {0}".format(omxdeb_file), shell=True)
        os.remove(omxdeb_file)
    if stat.S_ISCHR(os.stat("/dev/vchiq").st_mode) is True:
        print("Adding udev rule for /dev/vchiq")
        subprocess.run("""
echo 'SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"' > /etc/udev/rules.d/10-vchiq-permissions.rules
usermod -aG video {0}
        """.format(USERNAMEVAR))

# desktopomx section
if args.desktopomx is True:
    yt_script = """#!/bin/bash -e
if [ -z "$1" ]; then
	echo "No url. Exiting."
	exit 0;
else
	YT_URL="$1"
fi
if [ ! -z "$2" ]; then
	OMXOPTS="-l $2"
else
	OMXOPTS=""
fi
echo "Getting URL for $YT_URL"
OMXURL="$(youtube-dl -g -f best $YT_URL)"
echo "Playing $OMXURL"
omxplayer -o both "$OMXURL" "$OMXOPTS"
"""
    yt_file = "/usr/local/bin/yt"
    print("Writing {0}".format(yt_file))
    with open(yt_file, 'w') as yt_file_write:
        yt_file_write.write(yt_script)
    os.chmod(yt_file, 0o777)

    ytclip_script = """#!/bin/bash -x
YTURL="$(xclip -selection clipboard -o)"
if ! echo "$YTURL" | grep -iq youtube; then
	echo "Error. Clipboard contains $YTURL"
else
	echo "Playing $YTURL"
	yt "$YTURL"
fi
sleep 1
"""
    ytclip_file = "/usr/local/bin/yt"
    print("Writing {0}".format(ytclip_file))
    with open(ytclip_file, 'w') as ytclip_file_write:
        ytclip_file_write.write(ytclip_script)
    os.chmod(ytclip_file, 0o777)

    userdesktop = USERHOME + "/Desktop"
    if os.path.isdir(userdesktop) is True:
        ytclipdesktop_script = """#!/usr/bin/env xdg-open
[Desktop Entry]
Type=Application
Terminal=true
Exec=/usr/local/bin/ytclip
Name=YoutubeOMX
Comment=Youtube + OMXPlayer clipboard script
"""
        ytclipdesktop_file = "/usr/local/bin/yt"
        print("Writing {0}".format(ytclipdesktop_file))
        with open(ytclipdesktop_file, 'w') as ytclipdesktop_file_write:
            ytclip_file_write.write(ytclipdesktop_script)
        os.chmod(ytclipdesktop_file, 0o777)

# ppa section
if args.ppa is True:
    print("Installing optional RPi ppa and libraspberrypi-dev.")
    subprocess.run("""
    add-apt-repository -y "deb http://ppa.launchpad.net/ubuntu-raspi2/ppa/ubuntu xenial main"
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7876AE518CBCF2F2
    apt-get update
    apt-get install -y libraspberrypi-dev
    """, shell=True)
