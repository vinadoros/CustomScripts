#!/usr/bin/env python3
"""Clone and update CustomScripts."""

# Python includes.
import argparse
import json
import os
import shutil
import sys
import subprocess
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()

# Get arguments
parser = argparse.ArgumentParser(description='Clone and update CustomScripts.')
parser.add_argument("-r", "--repo", help='Repository to clone from Github', default="ramesh45345/CustomScripts")
parser.add_argument("-p", "--clonepath", help='Run Extra Scripts')
parser.add_argument("-v", "--variablefile", help='Run Extra Scripts', default=os.path.join(USERHOME, "privateconfig.json"))

# Save arguments.
args = parser.parse_args()

# Get variables
if args.clonepath is None:
    if CFunc.is_windows() is True:
        args.clonepath = USERHOME
    else:
        args.clonepath = os.path.join(os.sep, "opt")

# Get external variables from bash file.
variablefile = args.variablefile
if os.path.isfile(args.variablefile):
    variablefile = os.path.abspath(args.variablefile)
    print("Variable File {0} will be used.".format(variablefile))

# Save the repo name (after the slash) and the user (before the slash).
fullrepo = args.repo
repouser = fullrepo.split("/")[0]
reponame = fullrepo.split("/")[1]
print("Repo to clone: {0}/{1}".format(repouser, reponame))
if os.path.isdir(args.clonepath):
    clonepath = os.path.abspath(args.clonepath)
    clonepath_final = os.path.join(clonepath, reponame)
    print("Path to clone into: {0}".format(clonepath_final))
else:
    sys.exit("ERROR: Clone path {0} is not a valid folder.".format(args.clonepath))


### Begin Code ###
# Clone if doesn't exist.
if not os.path.isdir(clonepath_final):
    subprocess.run(['git', 'clone', "https://github.com/{0}.git".format(fullrepo), clonepath_final], check=True)
# Git pull.
os.chdir(clonepath_final)
subprocess.run(['git', 'config', 'remote.origin.url', "https://github.com/{0}.git".format(fullrepo)], check=True)
subprocess.run(['git', 'pull'], check=True)

# If variables were sourced, set remote details for comitting.
if os.path.isfile(variablefile):
    print("Adding commit information for {0} github account.".format(reponame))
    with open(variablefile, 'r') as variablefile_handle:
        json_privdata = json.load(variablefile_handle)
    os.chdir(clonepath_final)
    subprocess.run(['git', 'config', 'remote.origin.url', "git@gitserv:{0}.git".format(fullrepo)], check=True)
    subprocess.run(['git', 'config', 'push.default', 'simple'], check=True)
    subprocess.run(['git', 'config', 'user.name', json_privdata['GITHUBCOMMITNAME']], check=True)
    subprocess.run(['git', 'config', 'user.email', json_privdata['GITHUBCOMMITEMAIL']], check=True)

# Update scripts folder every hour.
# Make systemd service and timer if available
if shutil.which("systemctl"):
    # Systemd service
    CSUpdate_SystemUnitText = """[Unit]
Description=Service for CSUpdate
After=network-online.target graphical.target

[Service]
Type=simple
User={username}
ExecStart=/bin/sh -c "cd {clonepath_final}; git pull"
Restart=on-failure
RestartSec=60s
StartLimitBurst=4""".format(username=USERNAMEVAR, clonepath_final=clonepath_final)
    CFunc.systemd_createsystemunit("csupdate.service", CSUpdate_SystemUnitText)
    # Systemd timer
    CSUpdate_SystemTimerText = """[Unit]
Description=Timer for CSupdate

[Timer]
OnBootSec=15sec
OnActiveSec=15min

[Install]
WantedBy=timers.target"""
    SystemdSystemUnitPath = os.path.join(os.sep, "etc", "systemd", "system")
    fullunitpath = os.path.join(SystemdSystemUnitPath, "csupdate.timer")
    # Write the unit file.
    print("Creating {0}.".format(fullunitpath))
    with open(fullunitpath, 'w') as fullunitpath_write:
        fullunitpath_write.write(CSUpdate_SystemTimerText)
    # Enable the timer
    subprocess.run("systemctl daemon-reload", shell=True)
    subprocess.run("systemctl enable {0}".format("csupdate.timer"), shell=True)
    # Remove the cron script if it exists.
    if os.path.isfile("/etc/cron.hourly/{0}".format(reponame)):
        os.remove("/etc/cron.hourly/{0}".format(reponame))
# Fall-back to cron script if systemd is not available.
elif os.path.isdir("/etc/cron.hourly"):
    with open("/etc/cron.hourly/{0}".format(reponame), 'w') as file:
        file.write('''#!{2}
echo "Executing \$0"
su {0} -s /bin/sh <<'EOL'
    cd {1}
    git pull
EOL
'''.format(USERNAMEVAR, clonepath_final, shutil.which("bash")))
    # Make script executable
    os.chmod("/etc/cron.hourly/{0}".format(reponame), 0o777)

# Set permissions of cloned folder
if CFunc.is_windows() is False:
    subprocess.run("chown -R {0}:{1} {2}".format(USERNAMEVAR, USERGROUP, clonepath_final), shell=True)
    os.chmod(clonepath_final, 0o777)
