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
parser.add_argument("-x", "--x2go", help="Install x2go.", action="store_true")

# Save arguments.
args = parser.parse_args()

# Exit if not root.
if os.geteuid() is not 0:
    sys.exit("\nError: Please run this script as root.\n")

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()
MACHINEARCH = CFunc.machinearch()
print("Username is:", USERNAMEVAR)
print("Group Name is:", USERGROUP)
# Print out configuration information
print("VNC systemd service config flag is", args.vncsd)
print("x0vnc config flag is", args.x0vnc)
print("x2go config flag is", args.x2go)


if args.noprompt is False:
    input("Press Enter to continue.")


# Install xfce for vncsd and x2go.
if args.vncsd is True or args.x2go is True:
    print("Installing xfce.")
    if shutil.which("zypper"):
        CFunc.zpinstall("openbox xfce4-panel")
    elif shutil.which("dnf"):
        CFunc.dnfinstall("openbox xfce4-panel")
    elif shutil.which("apt-get"):
        CFunc.aptinstall("openbox xfce4-panel")

# Install vnc for vncsd and x0vnc.
if args.vncsd is True or args.x0vnc is True:
    print("Installing vnc.")
    if shutil.which("zypper"):
        CFunc.zpinstall("tigervnc autocutsel")
    elif shutil.which("dnf"):
        CFunc.dnfinstall("tigervnc tigervnc-server")
    elif shutil.which("apt-get"):
        CFunc.aptinstall("tigervnc-standalone-server vnc4server autocutsel")

# Create vnc folders
VncUserFolder = USERHOME + "/.vnc"
if args.vncsd is True or args.x0vnc is True:
    if not os.path.isdir(VncUserFolder):
        os.makedirs(VncUserFolder, 0o700, exist_ok=True)

# Openbox and XFCE configuration
VncXstartupFile = VncUserFolder + '/xstartup'
OpenboxConfigFolder = USERHOME + "/.config/openbox"
OpenboxConfigFile = OpenboxConfigFolder + "/autostart"
if args.vncsd is True or args.x2go is True:
    with open(VncXstartupFile, 'w') as VncXstartupFile_handle:
        VncXstartupFile_handle.write("""#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
# Execute this session. Add more sessions as necessary to autoselect.
if type mate-session; then
	exec mate-session
elif type openbox-session; then
	exec openbox-session
fi
""")
    os.chmod(VncXstartupFile, 0o777)
    # Openbox configuration.
    os.makedirs(OpenboxConfigFolder, exist_ok=True)
    with open(OpenboxConfigFile, 'w') as OpenboxConfigFile_handle:
        OpenboxConfigFile_handle.write("{0} &".format(shutil.which("xfce4-panel")))

# VNC Password config
VncPasswordRootPath = "/etc"
VncPasswordPath = VncPasswordRootPath + "/vncpasswd"
XhostLocation = shutil.which("xhost")
if args.vncsd is True or args.x0vnc is True:
    # Check if the password has already been set.
    if not os.path.isfile(VncPasswordPath):
        # Loop until the password has been successfully saved.
        VncPassReturnCode = 1
        while VncPassReturnCode is not 0:
            print("Enter a VNC Password (stored in {0}).".format(VncPasswordPath))
            status = subprocess.run("vncpasswd {0}".format(VncPasswordPath), shell=True)
            VncPassReturnCode = status.returncode
        # Set permissions for password file.
        shutil.chown(VncPasswordPath, USERNAMEVAR, USERGROUP)
        os.chmod(VncPasswordPath, 0o444)
    # Add autocutsel configuration.
    XinitrcFolder = "/etc/X11/xinit/xinitrc.d"
    XinitrcAutocutselConfigFile = XinitrcFolder + "/40-autocutsel.sh"
    if os.path.isdir(XinitrcFolder):
        print("Creating {0}.".format(XinitrcAutocutselConfigFile))
        with open(XinitrcAutocutselConfigFile, 'w') as XinitrcConfig_Handle:
            XinitrcConfig_Handle.write("#!/bin/bash\nautocutsel -fork &")
        os.chmod(XinitrcAutocutselConfigFile, 0o777)
    else:
        print("{0} does not exist. Not creating autocustsel configuration.".format(XinitrcFolder))

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
ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill :5 > /dev/null 2>&1 || :'
ExecStart={vncservpath} :5 -geometry 1024x768 -fg -alwaysshared -rfbport 5905 -rfbauth "{vncpasspath}" -auth ~/.Xauthority
ExecStop=/usr/bin/vncserver -kill :5
PIDFile={userhome}/.vnc/%H:5.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target""".format(username=USERNAMEVAR, userhome=USERHOME, vncpasspath=VncPasswordPath, vncservpath=shutil.which("vncserver"))
    CFunc.systemd_createsystemunit("vncuser.service", VncSystemUnitText)

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

# Config for x2go
if args.x2go is True:
    print("Installing x2go.")
    if shutil.which("zypper"):
        CFunc.zpinstall("x2goserver")
    elif shutil.which("dnf"):
        CFunc.dnfinstall("x2goserver fuse-sshfs")
    elif shutil.which("apt-get"):
        CFunc.addppa("ppa:x2go/stable")
        CFunc.aptinstall("x2goserver x2goserver-xsession sshfs")

# Ensure ownerships are correct
if os.path.isdir(VncUserFolder):
    subprocess.run("chown -R {0}:{1} {2}".format(USERNAMEVAR, USERGROUP, VncUserFolder), shell=True)
subprocess.run("chown -R {0}:{1} {2}".format(USERNAMEVAR, USERGROUP, USERHOME + "/.config"), shell=True)
