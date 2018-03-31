#!/usr/bin/env python3
"""Configure enhancements for shell."""

# Python includes.
import os
import grp
import pwd
import sys
import subprocess
import shutil
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

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
# Note: This folder is the root home folder if this script is run as root.
USERHOME = os.path.expanduser("~")
ROOTHOME = os.path.expanduser("~root")
# This folder is the above detected user's home folder if this script is run as root.
USERVARHOME = os.path.expanduser("~{0}".format(USERNAMEVAR))

# Detect OS information
distro, debrelease = CFunc.detectdistro()
print("Distro is {0}.".format(distro))
print("Release is {0}.".format(debrelease))

# Ensure that certain commands exist.
cmdcheck = ["chsh"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))


### Functions ###
def gitclone(url, destination):
    """If destination exists, do a git pull, otherwise git clone"""
    abs_dest = os.path.abspath(destination)
    if os.path.isdir(abs_dest):
        print("{0} exists. Pulling changes.".format(abs_dest))
        subprocess.run("cd {0}; git pull".format(abs_dest), shell=True)
    else:
        print("Cloning to {0}".format(abs_dest))
        subprocess.run("git clone {0} {1}".format(url, destination), shell=True)


### Generic Section ###
# Create "a" script
ascript_path = os.path.join("/", "usr", "local", "bin", "a")
if os.access(os.path.dirname(ascript_path), os.W_OK):
    print("Writing {0}".format(ascript_path))
    with open(ascript_path, 'w') as file:
        file.write("""#!/bin/bash
# Set root and non-root cmds.
if [ $(id -u) != "0" ]; then
    SUDOCMD="sudo"
    # Detect the normal user
    if [[ ! -z "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
        export USERNAMEVAR=$SUDO_USER
    elif [ "$USER" != "root" ]; then
        export USERNAMEVAR=$USER
    else
        export USERNAMEVAR=$(id 1000 -un)
    fi
else
    SUDOCMD=""
    USERNAMEVAR="$USERNAME"
fi
CUSTOMSCRIPTPATH="%s"
function sl () {
    sudo bash
}
if [ $(id -u) != "0" ]; then
    function pc () {
        EXISTPATH="$(pwd)"
        cd "$CUSTOMSCRIPTPATH"
        git fetch --all
        git diff
        git status
        if [ ! -z "$1" ]; then
            git add -A
            git commit -m "$1"
            git pull
            git push
        else
            echo "No commit message entered. Exiting."
        fi
        git pull
        cd "$EXISTPATH"
        unset EXISTPATH
    }
fi
function start () {
    echo "Starting systemd service $@."
    $SUDOCMD systemctl start "$@"
    $SUDOCMD systemctl status -l "$@"
}
function stop () {
    echo "Stopping systemd service $@."
    $SUDOCMD systemctl stop "$@"
    $SUDOCMD systemctl status -l "$@"
}
function en () {
    echo "Enabling systemd service $@."
    $SUDOCMD systemctl enable "$@"
    $SUDOCMD systemctl status -l "$@"
}
function dis () {
    echo "Disabling systemd service $@."
    $SUDOCMD systemctl disable "$@"
    $SUDOCMD systemctl status -l "$@"
}
function res () {
    echo "Restarting systemd service $@."
    $SUDOCMD systemctl restart "$@"
    $SUDOCMD systemctl status -l "$@"
}
function st () {
    echo "Getting status for systemd service $@."
    $SUDOCMD systemctl status -l "$@"
}
function dr () {
    echo "Executing systemd daemon-reload."
    $SUDOCMD systemctl daemon-reload
}
function startu () {
    echo "Starting systemd service $@ for user."
    systemctl --user start "$@"
    systemctl --user status -l "$@"
}
function stopu () {
    echo "Stopping systemd service $@ for user."
    systemctl --user stop "$@"
    systemctl --user status -l "$@"
}
function resu () {
    echo "Restarting systemd service $@ for user."
    systemctl --user restart "$@"
    systemctl --user status -l "$@"
}
function stu () {
    echo "Getting status for systemd service $@ for user."
    systemctl --user status -l "$@"
}
function dru () {
    echo "Executing systemd daemon-reload for user."
    systemctl --user daemon-reload
}

if type zypper &> /dev/null; then
    function ins () {
        echo "Installing $@."
        $SUDOCMD zypper install --no-recommends $@
    }
    function inr () {
        echo "Installing $@ with recommends."
        $SUDOCMD zypper install $@
    }
    function iny () {
        echo "Installing $@."
        $SUDOCMD zypper install -yl $@
    }
    function rmv () {
        echo "Removing $@."
        $SUDOCMD zypper remove -u $@
    }
    function se () {
        echo "Searching for $@."
        $SUDOCMD zypper search "$@"
        $SUDOCMD zypper info "$@"
    }
    function cln () {
        echo "No clean yet."
    }
    function up () {
        echo "Updating system."
        $SUDOCMD zypper up -yl --no-recommends
    }
    function dup () {
        echo "Dist-upgrading system."
        $SUDOCMD zypper dup --no-recommends
    }
elif type -p apt-get &> /dev/null; then
    function ins () {
        echo "Installing $@."
        $SUDOCMD apt-get install $@
    }
    function iny () {
        echo "Installing $@."
        $SUDOCMD apt-get install -y $@
    }
    function afix () {
        echo "Running apt-get -f install."
        $SUDOCMD apt-get -f install
    }
    function rmv () {
        echo "Removing $@."
        $SUDOCMD apt-get --purge remove $@
    }
    function agu () {
        echo "Updating Repos."
        $SUDOCMD apt-get update
    }
    function se () {
        echo "Searching for $@."
        apt-cache search $@
        echo "Policy for $@."
        apt-cache policy $@
    }
    function cln () {
        echo "Auto-cleaning cache."
        $SUDOCMD apt-get autoclean
        echo "Auto-removing packages."
        $SUDOCMD apt-get autoremove --purge
    }
    function up () {
        echo "Updating and Dist-upgrading system."
        $SUDOCMD apt-get update
        $SUDOCMD apt-get dist-upgrade
    }
elif type dnf &> /dev/null || type yum &> /dev/null; then
    if type dnf &> /dev/null; then
        PKGMGR=dnf
    elif type yum &> /dev/null; then
        PKGMGR=yum
    fi

    function ins () {
        echo "Installing $@."
        $SUDOCMD $PKGMGR install $@
    }
    function iny () {
        echo "Installing $@."
        $SUDOCMD $PKGMGR install -y $@
    }
    function rmv () {
        echo "Removing $@."
        $SUDOCMD $PKGMGR remove $@
    }
    function se () {
        echo -e "\nSearching for $@."
        $SUDOCMD $PKGMGR search "$@"
        echo -e "\nSearching installed packages for $@."
        $SUDOCMD $PKGMGR list installed | grep -i "$@"
        echo -e "\nInfo for $@."
        $SUDOCMD $PKGMGR info "$@"
    }
    function cln () {
        echo "Auto-removing packages."
        $SUDOCMD $PKGMGR autoremove
    }
    function up () {
        echo "Updating system."
        $SUDOCMD $PKGMGR update -y
    }
fi

# Run options passed.
"$@"
""" % SCRIPTDIR)
    # C-style printf string formatting was used to avoid collision with curly braces above.
    # https://docs.python.org/3/library/stdtypes.html#old-string-formatting
    os.chmod(ascript_path, 0o777)
else:
    print("ERROR: {0} not writeable.".format(os.path.dirname(ascript_path)))


######### Bash Section #########
# Generate profile file.
customprofile_path = os.path.join("/", "etc", "profile.d", "rcustom.sh")
# Check if the profile.d folder exists.
if os.path.isdir(os.path.dirname(customprofile_path)) and os.access(os.path.dirname(customprofile_path), os.W_OK):
    print("Writing {0}".format(customprofile_path))
    with open(customprofile_path, 'w') as file:
        file.write("""#!/bin/sh --this-shebang-is-just-here-to-inform-shellcheck--

# Expand $PATH to include the CustomScripts path.
if [ "${{PATH#*{0}}}" = "${{PATH}}" ] && [ -d "{0}" ]; then
    export PATH=$PATH:{0}
fi

# Set editor to nano
if [ -z "$EDITOR" ] || [ "$EDITOR" != "nano" ]; then
    export EDITOR=nano
fi

""".format(SCRIPTDIR))
else:
    print("ERROR: {0} is not writeable.".format(os.path.dirname(customprofile_path)))

# Generate bash script
BASHSCRIPT = "alias la='ls -lah --color=auto'"

# Set bash script
BASHSCRIPTPATH = os.path.join(USERHOME, ".bashrc")
if os.geteuid() is 0:
    BASHSCRIPTUSERPATH = os.path.join("{0}", ".bashrc").format(USERVARHOME)

# Remove existing bash scripts and copy skeleton.
if os.path.isfile(BASHSCRIPTPATH):
    os.remove(BASHSCRIPTPATH)
if os.geteuid() is 0:
    if os.path.isfile(BASHSCRIPTUSERPATH):
        os.remove(BASHSCRIPTUSERPATH)
# Skeleton will get overwritten by bash-it below, this is left here just in case it is needed in the future.
if os.path.isfile("/etc/skel/.bashrc"):
    shutil.copy("/etc/skel/.bashrc", BASHSCRIPTPATH)
    if os.geteuid() is 0:
        shutil.copy("/etc/skel/.bashrc", BASHSCRIPTUSERPATH)
        shutil.chown(BASHSCRIPTUSERPATH, USERNAMEVAR, USERGROUP)

# Install bash-it before modifying bashrc (which automatically deletes bashrc)
# Only do it if the current user can write to opt
if os.access("/opt", os.W_OK):
    if not os.path.isdir("/opt/bash-it"):
        subprocess.run("git clone https://github.com/Bash-it/bash-it /opt/bash-it", shell=True)
    else:
        subprocess.run("cd /opt/bash-it; git checkout -f; git pull", shell=True)
    subprocess.run("chmod a+rwx -R /opt/bash-it", shell=True)
if os.path.isdir("/opt/bash-it"):
    subprocess.run("""
    [ "$(id -u)" = "0" ] &&    HOME={0}
    /opt/bash-it/install.sh --silent
    """.format(ROOTHOME), shell=True)
    subprocess.run("""sed -i "s/BASH_IT_THEME=.*/BASH_IT_THEME='powerline'/g" {0}""".format(BASHSCRIPTPATH), shell=True)
    if os.geteuid() is 0:
        subprocess.run('su {0} -s {1} -c "/opt/bash-it/install.sh --silent"'.format(USERNAMEVAR, shutil.which("bash")), shell=True)
        subprocess.run("""sed -i "s/BASH_IT_THEME=.*/BASH_IT_THEME='powerline'/g" {0}""".format(BASHSCRIPTUSERPATH), shell=True)

# Install bash script
BASHSCRIPT_VAR = open(BASHSCRIPTPATH, mode='a')
BASHSCRIPT_VAR.write(BASHSCRIPT)
BASHSCRIPT_VAR.close()
os.chmod(BASHSCRIPTPATH, 0o644)
if os.geteuid() is 0:
    BASHSCRIPTUSER_VAR = open(BASHSCRIPTUSERPATH, mode='a')
    BASHSCRIPTUSER_VAR.write(BASHSCRIPT)
    BASHSCRIPTUSER_VAR.close()
    os.chmod(BASHSCRIPTUSERPATH, 0o644)
    shutil.chown(BASHSCRIPTUSERPATH, USERNAMEVAR, USERGROUP)

######### Zsh Section #########
# Check if zsh exists
if shutil.which('zsh'):
    ZSHPATH = shutil.which('zsh')
    # Set Zsh as default shell for the user.
    if not os.getenv("SHELL").endswith("zsh"):
        # Change the shell for the non-root user if running as root.
        if os.geteuid() is 0:
            subprocess.run('chsh -s {ZSHPATH} {USERNAMEVAR}'.format(USERNAMEVAR=USERNAMEVAR, ZSHPATH=ZSHPATH), shell=True)
        else:
            subprocess.run('chsh -s {ZSHPATH}'.format(ZSHPATH=ZSHPATH), shell=True)

        # Install oh-my-zsh for user
        gitclone("git clone git://github.com/robbyrussell/oh-my-zsh.git {0}/.oh-my-zsh".format(USERHOME))
        # Install zsh-syntax-highlighting
        gitclone("git clone https://github.com/zsh-users/zsh-syntax-highlighting.git {0}/.oh-my-zsh/plugins/zsh-syntax-highlighting".format(USERHOME))
        # Install zsh-autosuggestions
        gitclone("git clone https://github.com/zsh-users/zsh-autosuggestions {0}/.oh-my-zsh/plugins/zsh-autosuggestions".format(USERHOME))

        # Determine which plugins to install
        ohmyzsh_plugins = "git systemd zsh-syntax-highlighting zsh-autosuggestions"
        if distro == "Ubuntu":
            ohmyzsh_plugins += " ubuntu"
        elif distro == "Fedora":
            ohmyzsh_plugins += " dnf"
        # Write zshrc
        zshrc_path = os.path.join(USERHOME, ".zshrc")
        print("Writing {0}".format(zshrc_path))
        with open(zshrc_path, 'w') as file:
            file.write("""export ZSH={0}/.oh-my-zsh
ZSH_THEME="agnoster"
plugins=( {1} )
source $ZSH/oh-my-zsh.sh""".format(USERHOME, ohmyzsh_plugins))

# Fix permissions of home folder if the script was run as root.
if os.geteuid() is 0:
    subprocess.run("chown {0}:{1} -R {2}".format(USERNAMEVAR, USERGROUP, USERHOME))

print("Script finished successfully.")
