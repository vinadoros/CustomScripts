#!/usr/bin/env python3
"""Create synergy-core configuration"""

# Python includes.
import argparse
import os
import platform
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
parser.add_argument("-s", "--server", help='Install configuration on startup as a server.', action="store_true")
parser.add_argument("-l", "--serverleftclient", help='Hostname of client to the left of the server.', default="LeftClient")
parser.add_argument("-r", "--serverrightclient", help='Hostname of client to the right of the server.', default="RightClient")
parser.add_argument("-c", "--client", help='Install configuration on startup as a client.', action="store_true")
parser.add_argument("-d", "--clienthost", help='Connect to this host when configured as a client.', default="InsertHostHere")
parser.add_argument("-z", "--compile", help='Compile synergy-core from source.', action="store_true")
parser.add_argument("-b", "--barrier", help='Use barrier instead of synergy. Use this option with no other options.', action="store_true")

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
print("Server config flag is", args.server)
if args.server is True:
    print("Left Client for server is", args.serverleftclient)
    print("Right Client for server is", args.serverrightclient)
print("Client config flag is", args.client)
if args.client is True:
    print("Client host is", args.clienthost)
if args.barrier is True:
    print("Compiling and installing barrier.")

### Functions ###
def deps_common():
    """Install dependancies common to both synergy and barrier"""
    if shutil.which("dnf"):
        print("Installing Fedora common requirements.")
        CFunc.dnfinstall("cmake make gcc-c++ libX11-devel libXtst-devel libXext-devel libXinerama-devel libcurl-devel avahi-compat-libdns_sd-devel openssl-devel rpm-build rpmlint")
    elif shutil.which("apt-get"):
        print("Installing Ubuntu common requirements.")
        CFunc.aptinstall("cmake make g++ xorg-dev libcurl4-openssl-dev libavahi-compat-libdnssd-dev libssl-dev libx11-dev")
def deps_synergy():
    """Install dependancies specific to synergy"""
    if shutil.which("dnf"):
        print("Installing Fedora synergy requirements.")
        CFunc.dnfinstall("qt-devel")
    elif shutil.which("apt-get"):
        print("Installing Ubuntu synergy requirements.")
        CFunc.aptinstall("libqt4-dev")
def deps_barrier():
    """Install dependancies specific to barrier"""
    if shutil.which("dnf"):
        print("Installing Fedora barrier requirements.")
        CFunc.dnfinstall("qt5-devel")
    elif shutil.which("apt-get"):
        print("Installing Ubuntu barrier requirements.")
        CFunc.aptinstall("qtdeclarative5-dev")


if args.noprompt is False:
    input("Press Enter to continue.")

# Global Variables
RepoClonePathRoot = os.path.join("/", "var", "tmp")

### Compile from source ###
if args.compile is True:
    print("Compiling from source.")
    deps_common()
    deps_synergy()
    # Clone synergy-core repository
    RepoClonePath = RepoClonePathRoot + "/synergy-core"
    subprocess.run('su {0} -c "git clone https://github.com/symless/synergy-core {1}"'.format(USERNAMEVAR, RepoClonePath), shell=True, check=True)
    # Compile and install synergy-core
    subprocess.run("""cd {1}
    mkdir -m 777 -p build
    cd build
    su {0} -c "cmake .."
    su {0} -c "make"
    install -m 755 -t /usr/local/bin bin/synergy-core bin/synergys bin/synergyc
    """.format(USERNAMEVAR, RepoClonePath), shell=True, check=True)
    # Remove git folder.
    if os.path.isdir(RepoClonePath):
        shutil.rmtree(RepoClonePath)

# https://github.com/symless/synergy-core/wiki/Command-Line
# https://github.com/symless/synergy-core/wiki/Text-Config

### Server Configuration ###
if args.server is True:
    # Systemd configuration
    Server_SystemdUnitText = """[Unit]
Description=Synergy Server service

[Service]
Type=simple
# Use Pre-hook to ensure Xorg is started.
ExecStartPre={1}
ExecStart={0} --server --no-daemon
Restart=on-failure
RestartSec=5s
TimeoutStopSec=7s

[Install]
WantedBy=default.target
""".format(shutil.which("synergy-core"), shutil.which("xhost"))
    CFunc.systemd_createuserunit("synserv.service", Server_SystemdUnitText)
    # Global server config
    Server_SynConfig = "/etc/synergy.conf"
    Server_SynConfig_Text = """# Synergy Server config file
# Be sure to add more aliases if needed.
section: screens
    LeftScreen:
    ServerScreen:
    RightScreen:
end

section: links
    ServerScreen:
        # the numbers in parentheses indicate the percentage of the screen's edge to be considered active for switching)
        right(0,100) = RightScreen
        left(0,100)  = LeftScreen
    # ServerScreen is to the right of LeftScreen
    LeftScreen:
        right = ServerScreen
    # ServerScreen is to the left of RightScreen
    RightScreen:
        left  = ServerScreen
end

section: aliases
    ServerScreen:
        # Insert hostname here.
        {2}
    LeftScreen:
        {0}
    RightScreen:
        {1}
end

section: options
    screenSaverSync = false
    win32KeepForeground = true
end
""".format(args.serverleftclient, args.serverrightclient, platform.node())
    # Write the config file.
    with open(Server_SynConfig, 'w') as synconf_write:
        synconf_write.write(Server_SynConfig_Text)
### Client Configuration ###
if args.client is True:
    # Systemd configuration
    Client_SystemdUnitText = """[Unit]
Description=Synergy Client service

[Service]
Type=simple
# Use Pre-hook to ensure Xorg is started.
ExecStartPre={2}
ExecStart={0} --client --no-daemon {1}
Restart=on-failure
RestartSec=5s
TimeoutStopSec=7s

[Install]
WantedBy=default.target
""".format(shutil.which("synergy-core"), args.clienthost, shutil.which("xhost"))
    CFunc.systemd_createuserunit("syncli.service", Client_SystemdUnitText)

if args.barrier is True:
    RepoClonePath = os.path.join(RepoClonePathRoot, "barrier")
    # Install the dependancies
    deps_common()
    deps_barrier()
    # Clone the repo
    CFunc.gitclone("https://github.com/debauchee/barrier", RepoClonePath)
    os.chdir(RepoClonePath)
    # Start the build.
    subprocess.run(os.path.join(RepoClonePath, "clean_build.sh"), shell=True)
    # Ensure user owns the folder before installation.
    subprocess.run("chown {0}:{1} -R {2}".format(USERNAMEVAR, USERGROUP, RepoClonePath), shell=True)
    # Copy built files.
    InstallPath = os.path.join("/", "usr", "local", "bin")
    os.chdir(os.path.join(RepoClonePath, "build"))
    subprocess.run("install -m 755 -t {0} bin/barrier bin/barriers bin/barrierc".format(InstallPath), shell=True)
    # Create desktop file
    barrierdesktop_text = """#!/usr/bin/env xdg-open
[Desktop Entry]
Type=Application
Terminal=false
Exec={0}
Name=Barrier
Comment=Barrier KVM Software""".format(os.path.join(InstallPath, "barrier"))
    barrierdesktop_file = os.path.join("/", "usr", "local", "share", "applications", "barrier.desktop")
    os.makedirs(os.path.dirname(barrierdesktop_file), exist_ok=True)
    with open(barrierdesktop_file, 'w') as file:
        file.write(barrierdesktop_text)
    os.chmod(barrierdesktop_file, 0o777)
    # Autostart synergy for the user.
    shutil.copy2(barrierdesktop_file, os.path.join(USERHOME, ".config", "autostart"))
    # Create autohide config for user if it does not already exist.
    barrier_userconfig = os.path.join(USERHOME, ".config", "Debauchee", "Barrier.conf")
    if not os.path.isfile(barrier_userconfig):
        os.makedirs(os.path.dirname(barrier_userconfig), exist_ok=True)
        with open(barrier_userconfig, 'w') as file:
            file.write("""[General]
autoHide=true
minimizeToTray=true""")
        subprocess.run("chown -R {0}:{1} {2}/.config".format(USERNAMEVAR, USERGROUP, USERHOME), shell=True)
    # Remove git folder.
    os.chdir("/")
    if os.path.isdir(RepoClonePath):
        shutil.rmtree(RepoClonePath)
