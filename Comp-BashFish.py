#!/usr/bin/env python3

# Python includes.
import os
import grp
import pwd
import sys
import subprocess
import shutil
import stat

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR=sys.path[0]

# Get non-root user information.
if os.getenv("SUDO_USER") != None and os.getenv("SUDO_USER") != "root":
    USERNAMEVAR=os.getenv("SUDO_USER")
elif os.getenv("USER") != "root":
    USERNAMEVAR=os.getenv("USER")
else:
    # https://docs.python.org/3/library/pwd.html
    USERNAMEVAR=pwd.getpwuid(1000)[0]
# https://docs.python.org/3/library/grp.html
USERGROUP=grp.getgrgid(pwd.getpwnam(USERNAMEVAR)[3])[0]
USERHOME=os.path.expanduser("~")

# Ensure that certain commands exist.
cmdcheck = ["chsh"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

######### Bash Section #########


######### Fish Section #########
# Check if fish exists
if shutil.which('fish'):
    FISHPATH = shutil.which('fish')
    # Set Fish as default shell if it exists.
    if not os.getenv("SHELL").endswith("fish"):
        subprocess.run('chsh -s {FISHPATH}'.format(FISHPATH=FISHPATH), shell=True)
        # Change the shell for the non-root user if running as root.
        if os.geteuid() == 0:
            subprocess.run('chsh -s {FISHPATH} {USERNAMEVAR}'.format(USERNAMEVAR=USERNAMEVAR, FISHPATH=FISHPATH), shell=True)

    # Generate fish script.
    FISHSCRIPT="""
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
	$SUDOCMD systemctl start $argv
	$SUDOCMD systemctl status -l $argv
end
function stop
	echo "Stopping systemd service $argv."
	$SUDOCMD systemctl stop $argv
	$SUDOCMD systemctl status -l $argv
end
function en
	echo "Enabling systemd service $argv."
	$SUDOCMD systemctl enable $argv
	$SUDOCMD systemctl status -l $argv
end
function dis
	echo "Disabling systemd service $argv."
	$SUDOCMD systemctl disable $argv
	$SUDOCMD systemctl status -l $argv
end
function res
	echo "Restarting systemd service $argv."
	$SUDOCMD systemctl restart $argv
	$SUDOCMD systemctl status -l $argv
end
function st
	echo "Getting status for systemd service $argv."
	$SUDOCMD systemctl status -l $argv
end
function dr
	echo "Executing systemd daemon-reload."
	$SUDOCMD systemctl daemon-reload
end

# Set package manager functions
if type -q yaourt
    function pmi
    	echo "Installing $argv or updating using pacman."
    	$SUDOCMD pacman -Syu --needed $argv
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
    	$SUDOCMD rm /var/lib/pacman/db.lck
    end
    function cln
    	echo "Removing (supposedly) uneeded packages."
    	pacman -Qdtq | $SUDOCMD pacman -Rs -
    end
    function rmv
    	echo "Removing $argv and dependancies using pacman."
    	$SUDOCMD pacman -Rsn $argv
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

else if type -q apt-get
    set -gx PATH $PATH /usr/local/sbin /usr/sbin /sbin
    function ins
    	echo "Installing $argv."
    	$SUDOCMD apt-get install $argv
    end
    function iny
    	echo "Installing $argv."
    	$SUDOCMD apt-get install -y $argv
    end
    function afix
    	echo "Running apt-get -f install."
    	$SUDOCMD apt-get -f install
    end
    function rmv
    	echo "Removing $argv."
    	$SUDOCMD apt-get --purge remove $argv
    end
    function agu
    	echo "Updating Repos."
    	$SUDOCMD apt-get update
    end
    function se
    	echo "Searching for $argv."
    	apt-cache search $argv
    	echo "Policy for $argv."
    	apt-cache policy $argv
    end
    function cln
    	echo "Auto-removing packages."
    	$SUDOCMD apt-get autoremove --purge
    end
    function up
    	echo "Updating and Dist-upgrading system."
    	$SUDOCMD apt-get update
    	$SUDOCMD apt-get dist-upgrade
    end
    function rmk
    	echo "Removing old kernels."
    	$SUDOCMD apt-get purge (ls -tr /boot/vmlinuz-* | head -n -2 | grep -v (uname -r) | cut -d- -f2- | awk '{{print "linux-image-" $0 "\\nlinux-headers-" $0}}')
    end

else if type -q dnf; or type -q yum
    if type -q dnf
        PKGMGR=dnf
    else if type -q yum
        PKGMGR=yum
    end

    function ins
    	echo "Installing $argv."
    	$SUDOCMD $PKGMGR install $argv
    end
    function iny
    	echo "Installing $argv."
    	$SUDOCMD $PKGMGR install -y $argv
    end
    function rmv
    	echo "Removing $argv."
    	$SUDOCMD $PKGMGR remove $argv
    end
    function se
    	echo "Searching for $argv."
    	$SUDOCMD $PKGMGR search $argv
    	echo "Searching installed packages for $argv."
    	$PKGMGR list installed | grep -i $argv
    end
    function cln
    	echo "Auto-removing packages."
    	$SUDOCMD $PKGMGR autoremove
    end
    function up
    	echo "Updating system."
    	$SUDOCMD $PKGMGR update -y
    end
end

""".format(SCRIPTDIR=SCRIPTDIR)

    # Set fish script
    if os.geteuid() == 0:
        FISHSCRIPTPATH="/root/.config/fish/config.fish"
        FISHSCRIPTUSERPATH=USERHOME+"/.config/fish/config.fish"
    else:
        FISHSCRIPTPATH=USERHOME+"/.config/fish/config.fish"

    # Remove existing fish scripts.
    os.remove(FISHSCRIPTPATH)
    if os.geteuid() == 0:
        os.remove(FISHSCRIPTUSERPATH)

    # Install fish script
    FISHSCRIPT_VAR = open(FISHSCRIPTPATH, mode='w')
    FISHSCRIPT_VAR.write(FISHSCRIPT)
    FISHSCRIPT_VAR.close()
    os.chmod(FISHSCRIPTPATH, 0o777)
    if os.geteuid() == 0:
        FISHSCRIPTUSER_VAR = open(FISHSCRIPTUSERPATH, mode='w')
        FISHSCRIPTUSER_VAR.write(FISHSCRIPT)
        FISHSCRIPTUSER_VAR.close()
        os.chmod(FISHSCRIPTUSERPATH, 0o777)

print("Script finished successfully.")
