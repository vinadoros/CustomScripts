#!/usr/bin/env python3
"""Clone and update CustomScripts."""

# Python includes.
import argparse
import os
import sys
import subprocess
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get non-root user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()

# Private variable file.
GITHUBCOMMITNAME = None
GITHUBCOMMITEMAIL = None
GITHUBRSAPUB = None

# Get arguments
parser = argparse.ArgumentParser(description='Clone and update CustomScripts.')
parser.add_argument("-r", "--repo", help='Repository to clone from Github', default="ramesh45345/CustomScripts")
parser.add_argument("-p", "--clonepath", help='Run Extra Scripts', default="/opt")
parser.add_argument("-v", "--variablefile", help='Run Extra Scripts', default="/usr/local/bin/privateconfig.sh")

# Save arguments.
args = parser.parse_args()

# Get external variables from bash file.
if os.path.isfile(args.variablefile):
    with open(args.variablefile) as fd:
        exec(fd.read())

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
    subprocess.run('git clone "https://github.com/{0}.git" {1}'.format(fullrepo, clonepath_final), shell=True)
# Git pull.
subprocess.run('cd {0}; git config remote.origin.url "https://github.com/{1}.git"; git pull'.format(clonepath_final, fullrepo), shell=True)

# If variables were sourced, set remote details for comitting.
if GITHUBCOMMITNAME and GITHUBCOMMITEMAIL and os.path.isfile(GITHUBRSAPUB):
    print("Adding commit information for {0} github account.".format(reponame))
    subprocess.run("""cd {0}
git config remote.origin.url "git@gitserv:{0}.git"
git config push.default simple
git config user.name "{1}"
git config user.email "{2}"
""".format(reponame, GITHUBCOMMITNAME, GITHUBCOMMITEMAIL), shell=True)

# Update scripts folder every hour.
if os.path.isdir("/etc/cron.hourly"):
    with open("/etc/cron.hourly/{0}".format(reponame), 'w') as file:
        file.write('''#!/bin/sh
echo "Executing \$0"
su {0} -s /bin/sh <<'EOL'
    cd {1}
    git pull
EOL
'''.format(USERNAMEVAR, clonepath_final))

# Set permissions of cloneed folder
subprocess.run("chown -R {0}:{1} {2}".format(USERNAMEVAR, USERGROUP, clonepath_final), shell=True)
os.chmod(clonepath_final, 0o777)
