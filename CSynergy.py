#!/usr/bin/env python3
"""Create synergy-core configuration"""

# Python includes.
import argparse
import os
import shutil
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
# Configure systemd paths
SystemdSystemUnitPath = "/etc/systemd/system/"
if not os.path.isdir(SystemdSystemUnitPath):
    sys.exit("\nError: Systemd system unit path {0} does not exist.\n".format(SystemdSystemUnitPath))
SystemdUserUnitPath = USERHOME + "/"


if args.noprompt is False:
    input("Press Enter to continue.")

# https://github.com/symless/synergy-core/wiki/Command-Line
# https://github.com/symless/synergy-core/wiki/Text-Config

### Server Configuration ###
if args.server is True:
    # Systemd configuration
    Server_SystemdUnitText = """[Unit]
Description=Synergy Server service

[Service]
Type=simple
ExecStart={0} --server
Restart=on-failure
RestartSec=5s
TimeoutStopSec=7s

[Install]
WantedBy=default.target
""".format(shutil.which("synergy-core"))
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
		right = ServerScreen, userenable=False
	# ServerScreen is to the left of RightScreen
	RightScreen:
		left  = ServerScreen
end

section: aliases
	LeftScreen:
		{0}
    RightScreen:
        {1}
end

section: options
    screenSaverSync = true
    win32KeepForeground = true
end
""".format(args.serverleftclient, args.serverrightclient)
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
ExecStart={0} --client --no-daemon {1}
Restart=on-failure
RestartSec=5s
TimeoutStopSec=7s

[Install]
WantedBy=default.target
""".format(shutil.which("synergy-core"), args.clienthost)
    CFunc.systemd_createuserunit("syncli.service", Client_SystemdUnitText)
