#!/usr/bin/env python3
"""Install Display Manager Configuration."""

# Python includes.``
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
parser = argparse.ArgumentParser(description='Configure the Display Manager.')
parser.add_argument("-a", "--autologin", help='Force automatic login in display managers.', action="store_true")

# Save arguments.
args = parser.parse_args()

# Get VM State
vmstatus = CFunc.getvmstate()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)


### LightDM Section ###
if shutil.which("lightdm"):
    print("\n Processing lightdm configuration.")
    if "autologin" not in open('/etc/group', 'r').read():
        subprocess.run("groupadd autologin", shell=True)
    subprocess.run("gpasswd -a {0} autologin".format(USERNAMEVAR), shell=True)
    # Enable autologin
    if vmstatus or args.autologin is True:
        if os.path.isfile("/etc/lightdm/lightdm.conf"):
            subprocess.run("sed -i 's/#autologin-user=/autologin-user={0}/g' /etc/lightdm/lightdm.conf".format(USERNAMEVAR), shell=True)
        os.makedirs("/etc/lightdm/lightdm.conf.d", exist_ok=True)
        with open('/etc/lightdm/lightdm.conf.d/12-autologin.conf', 'w') as file:
            file.write("""[SeatDefaults]
autologin-user={0}""".format(USERNAMEVAR))
# Enable listing of users
if os.path.isfile("/etc/lightdm/lightdm.conf"):
    subprocess.run("sed -i 's/#greeter-hide-users=false/greeter-hide-users=false/g' /etc/lightdm/lightdm.conf", shell=True)

# Synergyc host text file.
SynHostFile = "/usr/local/bin/synhost.txt"
if not os.path.isfile(SynHostFile):
    with open(SynHostFile, 'w') as file:
        file.write("HostnameHere")
    os.chmod(SynHostFile, 0o666)
    print("Be sure to change the hostname in {0}.")

# LightDM Startup Script
LDSTART = "/usr/local/bin/ldstart.sh"
with open(LDSTART, 'w') as file:
    file.write("""#!/bin/bash
echo "Executing $0"

# https://wiki.freedesktop.org/www/Software/LightDM/CommonConfiguration/
# https://bazaar.launchpad.net/~lightdm-team/lightdm/trunk/view/head:/data/lightdm.conf

SERVER="$(<{0})"

if [ -z $DISPLAY ]; then
    echo "Setting variables for xvnc."
    DISPLAY=:0
fi

if type -p barrierc &> /dev/null && [[ "$SERVER" != "HostnameHere" ]]; then
    echo "Starting Barrier client."
    barrierc "$SERVER"
elif type -p synergyc &> /dev/null && [[ "$SERVER" != "HostnameHere" ]]; then
    echo "Starting Synergy client."
    synergyc "$SERVER"
fi

if type -p x0vncserver &> /dev/null && [ -f /etc/vncpasswd ]; then
    echo "Starting vnc."
    x0vncserver -passwordfile /etc/vncpasswd -rfbport 5900 &
fi

# Don't run if gdm is running.
if type -p xset &> /dev/null && ! pgrep gdm &> /dev/null; then
    echo "Starting xset dpms."
    # http://shallowsky.com/linux/x-screen-blanking.html
    # http://www.x.org/releases/X11R7.6/doc/man/man1/xset.1.xhtml
    # Turn screen off in 60 seconds.
    xset s 60
    xset dpms 60 60 60
fi

exit 0
""".format(SynHostFile))
os.chmod(LDSTART, 0o777)

# LightDM Stop Script
LDSTOP = "/usr/local/bin/ldstop.sh"
with open(LDSTOP, 'w') as file:
    file.write("""#!/bin/bash
echo "Executing $0"

# Kill synergy/barrier client.
pgrep synergyc && killall synergyc
pgrep barrierc && killall barrierc

# Kill X VNC server.
if pgrep x0vncserver; then
    killall x0vncserver
fi

# Set xset parameters back to defaults.
if type -p xset &> /dev/null && ! pgrep gdm &> /dev/null; then
    xset s
fi

exit 0
""")
os.chmod(LDSTOP, 0o777)

# Run startup script
LightDM_Config = "/etc/lightdm/lightdm.conf"
if os.path.isfile(LightDM_Config):
    subprocess.run("""
    # Uncomment lines
    sed -i '/^#display-setup-script=.*/s/^#//g' {LightDM_Config}
    sed -i '/^#session-setup-script=.*/s/^#//g' {LightDM_Config}
    # Add startup scripts to session
    sed -i "s@display-setup-script=.*@display-setup-script={LDSTART}@g" {LightDM_Config}
    sed -i "s@session-setup-script=.*@session-setup-script={LDSTOP}@g" {LightDM_Config}
""".format(LightDM_Config=LightDM_Config, LDSTART=LDSTART, LDSTOP=LDSTOP), shell=True)
elif not os.path.isfile(LightDM_Config) and os.path.isdir("/etc/lightdm/lightdm.conf.d"):
    with open('/etc/lightdm/lightdm.conf.d/11-startup.conf', 'w') as file:
        file.write("""[Seat:*]
display-setup-script={LDSTART}
session-setup-script={LDSTOP}""".format(LDSTART=LDSTART, LDSTOP=LDSTOP))

### GDM Section ###
if shutil.which("gdm") or shutil.which("gdm3"):
    if shutil.which("gdm3"):
        GDMPATH = "/var/lib/gdm3"
        GDMETCPATH = "/etc/gdm3"
    elif shutil.which("gdm"):
        GDMPATH = "/var/lib/gdm"
        GDMETCPATH = "/etc/gdm"
    GDMUID = CFunc.subpout("id -u gdm")
    GDMGID = CFunc.subpout("id -g gdm")
    # Enable gdm autologin for virtual machines.
    if vmstatus or args.autologin is True:
        print("Enabling gdm autologin for {0}.".format(USERNAMEVAR))
        # https://afrantzis.wordpress.com/2012/06/11/changing-gdmlightdm-user-login-settings-programmatically/
        # Get dbus path for the user
        USER_PATH = CFunc.subpout("dbus-send --print-reply=literal --system --dest=org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts.FindUserByName string:{0}".format(USERNAMEVAR))
        # Send the command over dbus to freedesktop accounts.
        subprocess.run("dbus-send --print-reply --system --dest=org.freedesktop.Accounts {0} org.freedesktop.Accounts.User.SetAutomaticLogin boolean:true".format(USER_PATH), shell=True)
        # https://hup.hu/node/114631
        # Can check options with following command:
        # dbus-send --system --dest=org.freedesktop.Accounts --print-reply --type=method_call $USER_PATH org.freedesktop.DBus.Introspectable.Introspect
        # qdbus --system org.freedesktop.Accounts $USER_PATH org.freedesktop.Accounts.User.AutomaticLogin

    # Pulseaudio gdm fix
    # http://www.debuntu.org/how-to-disable-pulseaudio-and-sound-in-gdm/
    # https://bbs.archlinux.org/viewtopic.php?id=202915
    if os.path.isfile("/etc/pulse/default.pa"):
        print("Executing gdm pulseaudio fix.")
        PulsePath = os.path.join(GDMPATH, ".config", "pulse")
        os.makedirs(PulsePath, exist_ok=True)

        shutil.copy2("/etc/pulse/default.pa", os.path.join(PulsePath, "default.pa"))
        subprocess.run("""sed -i '/^load-module .*/s/^/#/g' '{0}'""".format(os.path.join(PulsePath, "default.pa")), shell=True)
        subprocess.run('chown -R {0}:{1} "{2}/"'.format(GDMUID, GDMGID, GDMPATH), shell=True)

    #### Enable synergy and vnc in gdm ####
    # https://help.gnome.org/admin/gdm/stable/configuration.html.en
    # https://forums-lb.gentoo.org/viewtopic-t-1027688.html
    # https://bugs.gentoo.org/show_bug.cgi?id=553446
    # https://major.io/2008/07/30/automatically-starting-synergy-in-gdm-in-ubuntufedora/

    # Disable Wayland in GDM
    if os.path.isfile(os.path.join(GDMETCPATH, "daemon.conf")):
        GDMCustomConf = os.path.join(GDMETCPATH, "daemon.conf")
    else:
        GDMCustomConf = os.path.join(GDMETCPATH, "custom.conf")
    if os.path.isfile(GDMCustomConf):
        subprocess.run("""
        sed -i '/^#WaylandEnable=.*/s/^#//' "{0}"
        sed -i 's/^WaylandEnable=.*/WaylandEnable=false/g' "{0}"
        """.format(GDMCustomConf), shell=True)

    # Start xvnc and synergy
    with open("/usr/share/gdm/greeter/autostart/gdm_start.desktop", 'w') as file:
        file.write("""[Desktop Entry]
Type=Application
Name=GDM Startup
X-GNOME-Autostart-enabled=true
X-GNOME-AutoRestart=true
Exec={0}
NoDisplay=true""".format(LDSTART))

    # Stop apps after login. Add this right after script declaration.
    subprocess.run("""#!/bin/bash
    if ! grep "^{LDSTOP}" "{GDMETCPATH}/PreSession/Default"; then
        sed -i "/#\!\/bin\/sh/a {LDSTOP}" "{GDMETCPATH}/PreSession/Default"
    fi
    """.format(LDSTOP=LDSTOP, GDMETCPATH=GDMETCPATH), shell=True)

### SDDM Section ###
if shutil.which("sddm"):
    print("\n Processing sddm configuration.")
    # Enable autologin
    if vmstatus or args.autologin is True:
        os.makedirs("/etc/sddm.conf.d", exist_ok=True)
        with open("/etc/sddm.conf.d/autologin.conf", 'w') as f:
            f.write("""[Autologin]
User={0}
Session=plasma.desktop
""".format(USERNAMEVAR))
