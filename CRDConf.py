#!/usr/bin/env python3
"""Install Remote Desktop."""

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
parser = argparse.ArgumentParser(description='Create synergy-core configuration.')
parser.add_argument("-n", "--noprompt", help='Do not prompt to continue.', action="store_true")
parser.add_argument("-s", "--vncsd", help='Install vnc as a systemd service.', action="store_true")
parser.add_argument("-v", "--x0vnc", help="Install vnc for the user's display.", action="store_true")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
CFunc.is_root(True)

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)
# Print out configuration information
print("VNC systemd service config flag is", args.vncsd)
print("x0vnc config flag is", args.x0vnc)

# Ensure that certain commands exist.
cmdcheck = ["vncserver"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

if args.noprompt is False:
    input("Press Enter to continue.")


# Create vnc folders
VncUserFolder = os.path.join(USERHOME, ".vnc")
if args.vncsd is True or args.x0vnc is True:
    if not os.path.isdir(VncUserFolder):
        os.makedirs(VncUserFolder, 0o700, exist_ok=True)

# Detect a few sessions, by order of preference.
VncSession = None
if shutil.which("mate-session"):
    VncSession = "mate-session"
elif shutil.which("startxfce4"):
    VncSession = "startxfce4"
elif shutil.which("gnome-session"):
    VncSession = "gnome-session"
elif shutil.which("openbox-session"):
    VncSession = "openbox-session"

# vnc/xstartup configuration
VncXstartupFile = os.path.join(VncUserFolder, 'xstartup')
if args.vncsd is True:
    with open(VncXstartupFile, 'w') as VncXstartupFile_handle:
        VncXstartupFile_handle.write("""#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# Enable clipboard sharing. Sometimes autocutsel doesn't work, so include vncconfig.
type autocutsel && autocutsel -fork
type vncconfig && vncconfig -nowin &
# Execute this session. Add more sessions as necessary to autoselect.
exec dbus-launch {0}
""".format(VncSession))
    os.chmod(VncXstartupFile, 0o777)

# VNC Password config
VncPasswordRootPath = os.path.join(os.sep, "etc")
VncPasswordPath = os.path.join(VncPasswordRootPath, "vncpasswd")
if args.vncsd is True or args.x0vnc is True:
    # Check if the password has already been set.
    if not os.path.isfile(VncPasswordPath):
        # Loop until the password has been successfully saved.
        VncPassReturnCode = 1
        while VncPassReturnCode != 0:
            print("Enter a VNC Password (stored in {0}).".format(VncPasswordPath))
            status = subprocess.run("vncpasswd {0}".format(VncPasswordPath), shell=True, check=True)
            VncPassReturnCode = status.returncode
        # Set permissions for password file.
        shutil.chown(VncPasswordPath, USERNAMEVAR, USERGROUP)
        os.chmod(VncPasswordPath, 0o444)
    # Add autocutsel configuration.
    if shutil.which("autocutsel"):
        XinitrcFolder = os.path.join(os.sep, "etc", "X11", "xinit", "xinitrc.d")
        XinitrcAutocutselConfigFile = os.path.join(XinitrcFolder, "40-autocutsel.sh")
        if os.path.isdir(XinitrcFolder):
            print("Creating {0}.".format(XinitrcAutocutselConfigFile))
            with open(XinitrcAutocutselConfigFile, 'w') as XinitrcConfig_Handle:
                XinitrcConfig_Handle.write("#!/bin/bash\nautocutsel -fork &")
            os.chmod(XinitrcAutocutselConfigFile, 0o777)
        else:
            print("{0} does not exist. Not creating autocustsel configuration.".format(XinitrcFolder))
    else:
        print("WARNING: autocutsel not found, not creating configuration.")

# Config for vncsd
if args.vncsd is True:
    VncSystemUnitText = """[Unit]
Description=Remote desktop service as user (VNC)
After=syslog.target network.target

[Service]
Type=simple
User={username}
PAMName=login

# Clean any existing files in /tmp/.X11-unix environment
ExecStartPre=/bin/sh -c '{vncservpath} -kill :5 > /dev/null 2>&1 || :'
ExecStart={vncservpath} :5 -localhost=1 -SecurityTypes none -geometry 1024x768 -fg -alwaysshared -rfbport 5905 -rfbauth "{vncpasspath}" -auth ~/.Xauthority
ExecStop={vncservpath} -kill :5
PIDFile={userhome}/.vnc/%H:5.pid
Restart=on-failure
RestartSec=10s
StartLimitBurst=10

[Install]
WantedBy=multi-user.target""".format(username=USERNAMEVAR, userhome=USERHOME, vncpasspath=VncPasswordPath, vncservpath=shutil.which("vncserver"))
    CFunc.systemd_createsystemunit("vncuser.service", VncSystemUnitText)
    print('Edit {0} with correct session. For example, "exec mate-session", or "exec openbox-session"'.format(VncXstartupFile))

# Config for x0vnc
if args.x0vnc is True:
    X0VncUserUnitText = """[Unit]
Description=TigerVNC server for user session.

[Service]
Type=simple
ExecStart={vncpath} -passwordfile {vncpass} -rfbport 5900
Restart=always
RestartSec=10s
TimeoutStopSec=7s

[Install]
WantedBy=default.target
""".format(vncpath=shutil.which("x0vncserver"), vncpass=VncPasswordPath)
    CFunc.systemd_createuserunit("vncx0.service", X0VncUserUnitText)

# Ensure ownerships are correct
if os.path.isdir(VncUserFolder):
    CFunc.chown_recursive(VncUserFolder, USERNAMEVAR, USERGROUP)
CFunc.chown_recursive(os.path.join(USERHOME, ".config"), USERNAMEVAR, USERGROUP)
