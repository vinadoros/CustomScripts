#!/usr/bin/env python3

# Python includes.
import os
import grp
import pwd
import sys
import subprocess
import shutil

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
# This folder is the above detected user's home folder if this script is run as root.
USERVARHOME = os.path.expanduser("~{0}".format(USERNAMEVAR))

# Ensure that certain commands exist.
cmdcheck = ["chsh"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))


######### Bash Section #########

# Generate bash script
BASHSCRIPT="""
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
export EDITOR=nano
if [ $(uname -m) != "armv7l" ]; then
	export XZ_OPT="-T0"
fi
alias la='ls -lah --color=auto'
# Add sbin to PATH
if ! echo $PATH | grep -q "/sbin"; then
    export PATH=$PATH:/sbin:/usr/sbin:/usr/local/sbin
fi
if timeout 3 test -d "$CUSTOMSCRIPTPATH" && ! echo $PATH | grep -iq "$CUSTOMSCRIPTPATH"; then
	export PATH=$PATH:$CUSTOMSCRIPTPATH
fi
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

# Set package manager functions
if type -p yaourt &> /dev/null; then
    function pmi () {
    	echo "Installing $@ or updating using pacman."
    	$SUDOCMD pacman -Syu --needed $@
    }
    function ins () {
    	echo "Installing $@ using AUR helper."
        if [ $(id -u) != "0" ]; then
            yaourt -ASa --needed $@
        else
            su $USERNAMEVAR -s /bin/bash -c "yaourt -ASa --needed $@"
        fi
    }
    function iny () {
    	echo "Installing $@ using AUR helper."
        if [ $(id -u) != "0" ]; then
            yaourt -ASa --needed --noconfirm $@
        else
            su $USERNAMEVAR -s /bin/bash -c "yaourt -ASa --needed --noconfirm $@"
        fi
    }
    function up () {
    	echo "Starting full system update using AUR helper."
        if [ $(id -u) != "0" ]; then
            yaourt -ASyua --needed --noconfirm
        else
            su $USERNAMEVAR -s /bin/bash -c "yaourt -ASyua --needed --noconfirm"
        fi
    }
    function rmd () {
    	echo "Removing /var/lib/pacman/db.lck."
    	$SUDOCMD rm /var/lib/pacman/db.lck
    }
    function cln () {
    	echo "Removing (supposedly) uneeded packages."
    	pacman -Qdtq | $SUDOCMD pacman -Rs -
    }
    function rmv () {
    	echo "Removing $@ and dependancies using pacman."
    	$SUDOCMD pacman -Rsn $@
    }
    function se () {
    	echo "Searching for $@ using AUR helper."
    	yaourt -Ss "$@"
    }
    function gitup () {
    	echo "Upgrading git packages from AUR."
        if [ $(id -u) != "0" ]; then
            yaourt -ASa --noconfirm $(pacman -Qq | grep -i "\-git")
        else
            su $USERNAMEVAR -s /bin/bash -c 'yaourt -ASa --noconfirm $(pacman -Qq | grep -i "\-git")'
        fi
    }
elif type zypper &> /dev/null; then
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
    	echo "Auto-removing packages."
    	$SUDOCMD apt-get autoremove --purge
    }
    function up () {
    	echo "Updating and Dist-upgrading system."
    	$SUDOCMD apt-get update
    	$SUDOCMD apt-get dist-upgrade
    }
    function rmk () {
    	echo "Removing old kernels."
    	$SUDOCMD apt-get purge $(ls -tr /boot/vmlinuz-* | head -n -2 | grep -v $(uname -r) | cut -d- -f2- | awk '{{print "linux-image-" $0 "\\nlinux-headers-" $0}}')
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
    	echo "Searching for $@."
    	$SUDOCMD $PKGMGR search "$@"
    	echo "Searching installed packages for $@."
    	$PKGMGR list installed | grep -i "$@"
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
""" % SCRIPTDIR
# C-style printf string formatting was used to avoid collision with curly braces above.
# https://docs.python.org/3/library/stdtypes.html#old-string-formatting

# Set bash script
BASHSCRIPTPATH=USERHOME+"/.bashrc"
if os.geteuid() is 0:
    BASHSCRIPTUSERPATH="{0}/.bashrc".format(USERVARHOME)

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
    subprocess.run("/opt/bash-it/install.sh --silent", shell=True)
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

######### Fish Section #########
# Check if fish exists
if shutil.which('fish'):
    FISHPATH = shutil.which('fish')
    # Set Fish as default shell if it exists.
    if not os.getenv("SHELL").endswith("fish"):
        subprocess.run('chsh -s {FISHPATH}'.format(FISHPATH=FISHPATH), shell=True)
        # Change the shell for the non-root user if running as root.
        if os.geteuid() is 0:
            subprocess.run('chsh -s {FISHPATH} {USERNAMEVAR}'.format(USERNAMEVAR=USERNAMEVAR, FISHPATH=FISHPATH), shell=True)

    # Generate fish script.
    FISHSCRIPT="""
# Set bobthefish options
set -g theme_display_user yes
# Set root and non-root cmds.
if [ (id -u) != "0" ]
    set SUDOCMD "sudo"
    # Detect the normal user
    if test $SUDO_USER; and [ $SUDO_USER != "root" ]
        set USERNAMEVAR $SUDO_USER
    else if [ $USER != "root" ]
        set USERNAMEVAR $USER
    else
        set USERNAMEVAR (id 1000 -un)
    end
else
    set SUDOCMD ""
    set USERNAMEVAR $USERNAME
end
set CUSTOMSCRIPTPATH "{SCRIPTDIR}"
# Set editor
set -gx EDITOR nano
if [ (uname -m) != "armv7l" ]
	set -gx XZ_OPT "-T0"
end
# Set sbin in path
if not echo $PATH | grep -q "/sbin"
    set -gx PATH $PATH /usr/local/sbin /usr/sbin /sbin
end
# Set Custom Scripts in path
if timeout 3 test -d "$CUSTOMSCRIPTPATH"
	set -gx PATH $PATH "$CUSTOMSCRIPTPATH"
end
function sl
	xhost +localhost >> /dev/null
	env DISPLAY=$DISPLAY sudo fish
end
if [ (id -u) != "0" ]
    function pc
    	set -x EXISTPATH (pwd)
    	cd "$CUSTOMSCRIPTPATH"
    	git fetch --all
    	git diff
    	git status
    	if not test -z $argv
    		git add -A
    		git commit -m "$argv"
    		git pull
    		git push
    	else
    		echo "No commit message entered. Exiting."
    	end
    	git pull
    	cd "$EXISTPATH"
    	set -e EXISTPATH
    end
end
function sst
	ssh -t $argv "tmux attach; or tmux new"
end
function start
	echo "Starting systemd service $argv."
	sudo systemctl start $argv
	sudo systemctl status -l $argv
end
function stop
	echo "Stopping systemd service $argv."
	sudo systemctl stop $argv
	sudo systemctl status -l $argv
end
function en
	echo "Enabling systemd service $argv."
	sudo systemctl enable $argv
	sudo systemctl status -l $argv
end
function dis
	echo "Disabling systemd service $argv."
	sudo systemctl disable $argv
	sudo systemctl status -l $argv
end
function res
	echo "Restarting systemd service $argv."
	sudo systemctl restart $argv
	sudo systemctl status -l $argv
end
function st
	echo "Getting status for systemd service $argv."
	sudo systemctl status -l $argv
end
function dr
	echo "Executing systemd daemon-reload."
	sudo systemctl daemon-reload
end

# Set package manager functions
if type -q yaourt
    function pmi
    	echo "Installing $argv or updating using pacman."
    	sudo pacman -Syu --needed $argv
    end
    function ins
    	echo "Installing $argv using AUR helper."
        if [ (id -u) != "0" ]
            yaourt -ASa --needed $argv
        else
            su $USERNAMEVAR -c "yaourt -ASa --needed $argv"
        end
    end
    function iny
    	echo "Installing $argv using AUR helper."
        if [ (id -u) != "0" ]
            yaourt -ASa --needed --noconfirm $argv
        else
            su $USERNAMEVAR -c "yaourt -ASa --needed --noconfirm $argv"
        end
    end
    function up
    	echo "Starting full system update using AUR helper."
        if [ (id -u) != "0" ]
            yaourt -ASyua --needed --noconfirm
        else
            su $USERNAMEVAR -c "yaourt -ASyua --needed --noconfirm"
        end
    end
    function rmd
    	echo "Removing /var/lib/pacman/db.lck."
    	sudo rm /var/lib/pacman/db.lck
    end
    function cln
    	echo "Removing (supposedly) uneeded packages."
    	pacman -Qdtq | sudo pacman -Rs -
    end
    function rmv
    	echo "Removing $argv and dependancies using pacman."
    	sudo pacman -Rsn $argv
    end
    function se
    	echo "Searching for $argv using AUR helper."
    	yaourt -Ss "$argv"
    end
    function gitup
    	echo "Upgrading git packages from AUR."
        if [ (id -u) != "0" ]
            yaourt -ASa --noconfirm (pacman -Qq | grep -i "\-git")
        else
            su $USERNAMEVAR -c 'yaourt -ASa --noconfirm (pacman -Qq | grep -i "\-git")'
        end
    end

else if type -q zypper;
    function ins
    	echo "Installing $argv."
    	sudo zypper install --no-recommends $argv
    end
    function inr
        echo "Installing $argv with recommends."
        sudo zypper install $argv
    end
    function iny
    	echo "Installing $argv."
    	sudo zypper install -yl $argv
    end
    function rmv
    	echo "Removing $argv."
    	sudo zypper remove -u $argv
    end
    function se
    	echo "Searching for $argv."
        sudo zypper search $argv
        sudo zypper info $argv
    end
    function cln
    	echo "No clean yet."
    end
    function up
    	echo "Updating system."
    	sudo zypper up -yl --no-recommends
    end
    function dup
        echo "Dist-upgrading system."
        sudo zypper dup --no-recommends
    end

else if type -q apt-get
    function ins
    	echo "Installing $argv."
    	sudo apt-get install $argv
    end
    function iny
    	echo "Installing $argv."
    	sudo apt-get install -y $argv
    end
    function afix
    	echo "Running apt-get -f install."
    	sudo apt-get -f install
    end
    function rmv
    	echo "Removing $argv."
    	sudo apt-get --purge remove $argv
    end
    function agu
    	echo "Updating Repos."
    	sudo apt-get update
    end
    function se
    	echo "Searching for $argv."
    	apt-cache search $argv
    	echo "Policy for $argv."
    	apt-cache policy $argv
    end
    function cln
    	echo "Auto-removing packages."
    	sudo apt-get autoremove --purge
    end
    function up
    	echo "Updating and Dist-upgrading system."
    	sudo apt-get update
    	sudo apt-get dist-upgrade
    end
    function rmk
    	echo "Removing old kernels."
    	sudo apt-get purge (ls -tr /boot/vmlinuz-* | head -n -2 | grep -v (uname -r) | cut -d- -f2- | awk '{{print "linux-image-" $0 "\\nlinux-headers-" $0}}')
    end

else if type -q dnf; or type -q yum
    if type -q dnf
        set PKGMGR dnf
    else if type -q yum
        set PKGMGR yum
    end

    function ins
    	echo "Installing $argv."
    	sudo $PKGMGR install $argv
    end
    function iny
    	echo "Installing $argv."
    	sudo $PKGMGR install -y $argv
    end
    function rmv
    	echo "Removing $argv."
    	sudo $PKGMGR remove $argv
    end
    function se
    	echo "Searching for $argv."
    	sudo $PKGMGR search $argv
    	echo "Searching installed packages for $argv."
    	sudo $PKGMGR list installed | grep -i $argv
    end
    function cln
    	echo "Auto-removing packages."
    	sudo $PKGMGR autoremove
    end
    function up
    	echo "Updating system."
    	sudo $PKGMGR update -y
    end
end

""".format(SCRIPTDIR=SCRIPTDIR)

    # Set fish script
    FISHSCRIPTPATH=USERHOME+"/.config/fish/config.fish"
    if os.geteuid() is 0:
        FISHSCRIPTUSERPATH="{0}/.config/fish/config.fish".format(USERVARHOME)

    # Create path if it doesn't existing
    os.makedirs(os.path.dirname(FISHSCRIPTPATH),exist_ok=True)
    if os.geteuid() is 0:
        os.makedirs(os.path.dirname(FISHSCRIPTUSERPATH),exist_ok=True)
        subprocess.run("chown -R {0}:{1} {2}/.config".format(USERNAMEVAR, USERGROUP, USERVARHOME), shell=True)

    # Remove existing fish scripts.
    if os.path.isfile(FISHSCRIPTPATH):
        os.remove(FISHSCRIPTPATH)
    if os.geteuid() is 0:
        if os.path.isfile(FISHSCRIPTUSERPATH):
            os.remove(FISHSCRIPTUSERPATH)

    # Install root fish script
    FISHSCRIPT_VAR = open(FISHSCRIPTPATH, mode='a')
    FISHSCRIPT_VAR.write(FISHSCRIPT)
    FISHSCRIPT_VAR.close()
    os.chmod(FISHSCRIPTPATH, 0o644)

    # Install fish script for user
    if os.geteuid() is 0:
        FISHSCRIPTUSER_VAR = open(FISHSCRIPTUSERPATH, mode='a')
        FISHSCRIPTUSER_VAR.write(FISHSCRIPT)
        FISHSCRIPTUSER_VAR.close()
        os.chmod(FISHSCRIPTUSERPATH, 0o644)
        subprocess.run("chown -R {0}:{1} {2}".format(USERNAMEVAR, USERGROUP, os.path.dirname(FISHSCRIPTUSERPATH)), shell=True)

    # Install fish utilities and plugins
    fish_testcmd = 'fish -c "omf update"'
    fish_installplugins = """
    # Install oh-my-fish
    if [ "$(id -u)" = "0" ]; then
    	HOME=/root
    fi
    cd /tmp
    git clone https://github.com/oh-my-fish/oh-my-fish
    cd oh-my-fish
    bin/install --offline --noninteractive
    cd /tmp
    rm -rf oh-my-fish
    # Install bobthefish theme
    fish -c "omf install bobthefish"
    """
    status = subprocess.run(fish_testcmd, shell=True)
    if status.returncode is not 0:
        print("Installing omf.")
        process = subprocess.run(fish_installplugins, shell=True)
    if os.geteuid() is 0:
        status = subprocess.run('su {0} -s {1} -c "omf update"'.format(USERNAMEVAR, shutil.which("fish")), shell=True)
        if status.returncode is not 0:
            print("Installing omf for {0}.".format(USERNAMEVAR))
            fish_installuserplugins = """
            # Install oh-my-fish
            cd /tmp
            git clone https://github.com/oh-my-fish/oh-my-fish userfish
            cd userfish
            su {0} -s {3} -c "bin/install --offline --noninteractive"
            cd /tmp
            rm -rf userfish
            # Install bobthefish theme
            su {0} -s {3} -c "omf install bobthefish"
            chown -R {0}:{1} {2}
            """.format(USERNAMEVAR, USERGROUP, os.path.dirname(FISHSCRIPTUSERPATH), shutil.which("fish"))
            status = subprocess.run(fish_installuserplugins, shell=True)

    # Personal note: To uninstall omf completely, use the following command as a normal user:
    # omf destroy; sudo rm -rf /root/.config/omf/ /root/.cache/omf/ /root/.local/share/omf/ ~/.config/omf/ ~/.cache/omf/ ~/.local/share/omf/

print("Script finished successfully.")
