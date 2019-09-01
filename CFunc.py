#!/usr/bin/env python3
"""General Python Functions"""

# Python includes.
import fnmatch
import logging
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

### Detect Windows Function ###
def is_windows():
    """Detect if OS is Windows."""
    pl_types = ["CYGWIN", "Windows"]
    if any(x in platform.system() for x in pl_types):
        return True
    return False


# Exclude imports not available on Windows.
if is_windows() is False:
    import grp
    import pwd

# Folder of this script
SCRIPTDIR = sys.path[0]


### Functions ###

### General helper functions ###
def subpout(cmd):
    """Get output from subprocess"""
    output = subprocess.run("{0}".format(cmd), shell=True, stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
    return output
def dlProgress(count, blockSize, totalSize):
    """Get the progress of a download"""
    percent = int(count * blockSize * 100 / totalSize)
    sys.stdout.write("\r" + "Progress...%d%%" % percent)
    # If the progress is 100 (or more), print a newline.
    if percent >= 100:
        sys.stdout.write("\n")
    sys.stdout.flush()
def downloadfile(url, localpath, filename=None, overwrite=False):
    """Retrieve a file and return its fullpath and filename"""
    # Get filename for extensions
    fileinfo = urllib.parse.urlparse(url)
    if filename is None:
        filename = urllib.parse.unquote(os.path.basename(fileinfo.path))
    fullpath = os.path.join(localpath, filename)
    # Remove the file if overwrite is specified.
    if overwrite is True and os.path.isfile(fullpath) is True:
        os.remove(fullpath)
    # Download the file if it doesn't exist.
    if os.path.isfile(fullpath) is False:
        # Download the file.
        print("Downloading {0} from {1}.".format(filename, url))
        urllib.request.urlretrieve(url, fullpath, reporthook=dlProgress)
        if not os.path.isfile(fullpath):
            sys.exit("File {0} not downloaded. Exiting.".format(filename))
    else:
        print("File {0} already exists. Skipping download.".format(fullpath))
    return (fullpath, filename)
def find_pattern_infile(file, find, printlines=False):
    """Find a pattern in a signle file"""
    abs_file = os.path.abspath(file)
    found = False
    if os.path.isfile(abs_file):
        with open(abs_file, 'r') as VAR:
            for line in VAR:
                if bool(re.search(find, line)):
                    found = True
                    if printlines is True:
                        print(line.strip())
    else:
        print("{0} file not found.".format(abs_file))
    return found
def find_replace(directory, find, replace, filePattern):
    """
    Find and replace recursively.
    https://stackoverflow.com/questions/4205854/python-way-to-recursively-find-and-replace-string-in-text-files
    """
    for walkresult in os.walk(os.path.abspath(directory)):
        for filename in fnmatch.filter(walkresult[2], filePattern):
            filepath = os.path.join(walkresult[0], filename)
            with open(filepath) as f:
                s = f.read()
            s = s.replace(find, replace)
            with open(filepath, "w") as f:
                f.write(s)
def gitclone(url, destination):
    """If destination exists, do a git pull, otherwise git clone"""
    abs_dest = os.path.abspath(destination)
    if os.path.isdir(abs_dest):
        print("{0} exists. Pulling changes.".format(abs_dest))
        subprocess.run("cd {0}; git checkout -f; git pull".format(abs_dest), shell=True)
    else:
        subprocess.run("git clone {0} {1}".format(url, destination), shell=True)
def log_config(logfile_path):
    """Configure logger, which outputs to file and stdout."""
    logging.basicConfig(
        format="%(message)s",
        level=logging.INFO,
        handlers=[
            logging.FileHandler(logfile_path, 'w'),
            logging.StreamHandler()
        ])
def log_subprocess_output(pipe):
    """Log piped output"""
    # b'\n'-separated lines
    for line in iter(pipe.readline, b''):
        # Remove the newlines and decode.
        logging.info('{0}'.format(line.strip().decode()))
def subpout_logger(cmd):
    """Run command which will output stdout to logger"""
    logging.info("Running command: {0}".format(cmd))
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True)
    with process.stdout:
        log_subprocess_output(process.stdout)
    exitcode = process.wait()
    return exitcode
### OS Functions ###
def os_type():
    """Get the operating system (kernel) type."""
    ostype = ""
    # Windows
    if is_windows() is True:
        ostype = "Windows"
    # Linux and FreeBSD
    elif shutil.which("uname"):
        ostype = subpout("uname -s")
    # Something else?
    else:
        ostype = "Unknown"
    return ostype
def getuserdetails(username):
    """Get group and home folder info about a particular user."""
    # https://docs.python.org/3/library/grp.html
    if is_windows() is False:
        usergroup = grp.getgrgid(pwd.getpwnam(username)[3])[0]
    else:
        usergroup = None
    userhome = os.path.expanduser("~{0}".format(username))
    return usergroup, userhome
def getnormaluser():
    """Auto-detect non-root user information."""
    if is_windows() is True:
        usernamevar = os.getlogin()
    elif os.getenv("SUDO_USER") not in ["root", None]:
        usernamevar = os.getenv("SUDO_USER")
    elif os.getenv("USER") not in ["root", None]:
        usernamevar = os.getenv("USER")
    else:
        # https://docs.python.org/3/library/pwd.html
        # Search through the user id range for a normal user.
        for userid in range(1000, 1100):
            try:
                usernamevar = pwd.getpwuid(userid)[0]
                # Stop when the first user is sucessfully found.
                break
            except KeyError:
                # Do nothing until the user id is sucessfully found.
                pass
    usergroup, userhome = getuserdetails(usernamevar)
    return usernamevar, usergroup, userhome
def machinearch():
    """Get the machine arch."""
    return platform.machine()
def getvmstate():
    """Determine what Virtual Machine guest is running under."""
    # Default state.
    vmstatus = None
    if os_type() == "Linux":
        # Detect QEMU
        with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
            if bool("QEMU" in VAR.read().strip()):
                vmstatus = "kvm"
        # Detect Virtualbox
        with open('/sys/devices/virtual/dmi/id/product_name', 'r') as VAR:
            if bool("VirtualBox" in VAR.read().strip()):
                vmstatus = "vbox"
        # Detect VMWare
        with open('/sys/devices/virtual/dmi/id/sys_vendor', 'r') as VAR:
            if bool("VMware" in VAR.read().strip()):
                vmstatus = "vmware"
    # For any OS with dmidecode, like FreeBSD
    elif shutil.which("dmidecode"):
        vmstatus_temp = subpout("dmidecode -s baseboard-product-name")
        if vmstatus_temp == "VirtualBox":
            vmstatus = "vbox"
        if vmstatus_temp == "VMware":
            vmstatus = "vmware"
    return vmstatus
def is_root(checkstate=True, state_exit=True):
    """
    Check if current user is root or not.
    Pass True if checking to make sure you are root, or False if you don't want to be root.
    """
    if is_windows() is False:
        actualstate = bool(os.geteuid() == 0)
        if actualstate != checkstate:
            # No match if actual state didn't match the expected state (checkstate).
            match = False
            if state_exit is True:
                sys.exit("\nError: Actual root state is {0}, expected {1}.\n".format(actualstate, checkstate))
            else:
                print("Actual root state is {0}, expected {1}.".format(actualstate, checkstate))
        else:
            match = True
        # Return result of root match check.
        return match
    else:
        # Windows should always return false for root.
        return False
def sudocmd(h=False):
    """Generate sudo command if not root."""
    sudo_cmd = ""
    if is_root(checkstate=False, state_exit=False):
        sudo_cmd = "sudo "
        if h is True:
            sudo_cmd += "-H "
    return sudo_cmd
def demote(user_uid, user_gid):
    """Demote to the specified user and group id."""
    def result():
        os.setgid(user_gid)
        os.setuid(user_uid)
    return result
def run_as_user(user_name, cmd, shell_cmd=None):
    """Run a command as the specified username."""
    cwd = os.getcwd()
    pw_record = pwd.getpwnam(user_name)
    user_name = pw_record.pw_name
    user_home_dir = pw_record.pw_dir
    user_uid = pw_record.pw_uid
    user_gid = pw_record.pw_gid
    env = os.environ.copy()
    env['HOME'] = user_home_dir
    env['LOGNAME'] = user_name
    env['PWD'] = cwd
    env['USER'] = user_name
    print("Running {0} as {1}".format(cmd, user_name))
    process = subprocess.Popen(cmd, preexec_fn=demote(user_uid, user_gid), cwd=cwd, env=env, shell=True, executable=shell_cmd)
    process.wait()
    return process.returncode
### Systemd Functions ###
def systemd_createsystemunit(sysunitname, sysunittext, sysenable=False):
    """Create a systemd system unit."""
    SystemdSystemUnitPath = os.path.join(os.sep, "etc", "systemd", "system")
    # Make sure systemd system unit path exists.
    if not os.path.isdir(SystemdSystemUnitPath):
        print("\nError: Systemd system unit path {0} does not exist.\n".format(SystemdSystemUnitPath))
        return 1
    fullunitpath = os.path.join(SystemdSystemUnitPath, sysunitname)
    # Write the unit file.
    print("Creating {0}.".format(fullunitpath))
    with open(fullunitpath, 'w') as fullunitpath_write:
        fullunitpath_write.write(sysunittext)
    # Enable the unit if specified.
    if sysenable is True:
        subprocess.run("systemctl daemon-reload", shell=True)
        subprocess.run("systemctl enable {0}".format(sysunitname), shell=True)
    else:
        print("{0} not enabled. Enable with systemctl enable {0}.".format(sysunitname))
    return 0
def systemd_createuserunit(userunitname, userunittext):
    """Create a systemd user unit."""
    # Get the normal user.
    USERNAMEVAR, USERGROUP, USERHOME = getnormaluser()
    # Set systemd user folder paths
    SystemdUser_UnitPath = USERHOME + "/.config/systemd/user"
    SystemdUser_DefaultTargetPath = SystemdUser_UnitPath + "/default.target.wants"
    # Create the foldrs if they don't exist
    os.makedirs(SystemdUser_UnitPath, exist_ok=True)
    os.makedirs(SystemdUser_DefaultTargetPath, exist_ok=True)
    # Create the default target.
    SystemdUser_DefaultTargetUnitFile = SystemdUser_DefaultTargetPath + "/default.target"
    print("Creating {0}".format(SystemdUser_DefaultTargetUnitFile))
    with open(SystemdUser_DefaultTargetUnitFile, 'w') as tgtunitfile_write:
        tgtunitfile_write.write("""[Unit]
Description=Default target
Requires=dbus.socket
AllowIsolate=true""")
    # Create the user unit file.
    SystemdUser_UnitFilePath = SystemdUser_UnitPath + "/" + userunitname
    print("Creating {0}.".format(SystemdUser_UnitFilePath))
    with open(SystemdUser_UnitFilePath, 'w') as userunitfile_write:
        userunitfile_write.write(userunittext)
    # Symlink the unit file in the default target.
    SystemdUser_DefaultTargetUserUnitSymlinkPath = SystemdUser_DefaultTargetPath + "/" + userunitname
    # Remove any existing item.
    if os.path.exists(SystemdUser_DefaultTargetUserUnitSymlinkPath):
        os.remove(SystemdUser_DefaultTargetUserUnitSymlinkPath)
    # Create the symlink.
    os.symlink(SystemdUser_UnitFilePath, SystemdUser_DefaultTargetUserUnitSymlinkPath)
    # Set proper ownership if running as root.
    if os.geteuid() is 0:
        subprocess.run("chown {0}:{1} -R {2}/.config".format(USERNAMEVAR, USERGROUP, USERHOME), shell=True)
    else:
        # Run daemon-reload if not running as root.
        subprocess.run("systemctl --user daemon-reload", shell=True)
    return 0
### Distro and Package Manager Specific Functions ###
# General Distro Functions
def detectdistro():
    """Detect Distribution and Release from LSB info"""
    lsb_distro = ""
    lsb_release = ""
    if os_type() == "Linux" and shutil.which("lsb_release"):
        lsb_distro = subpout("lsb_release -si")
        lsb_release = subpout("lsb_release -sc")
    else:
        lsb_distro = os_type()
    return (lsb_distro, lsb_release)
def AddUserAllGroups(username=None):
    """Add a given user to all reasonable groups."""
    # Detect user if not passed.
    if username is None:
        usertuple = getnormaluser()
        USERNAMEVAR = usertuple[0]
        USERGROUP = usertuple[1]
    else:
        USERNAMEVAR = username
    # Add normal user to all reasonable groups
    with open("/etc/group", 'r') as groups:
        grparray = []
        # Split the grouplist into lines
        grouplist = groups.readlines()
        # Iterate through all groups in grouplist
        for line in grouplist:
            # Remove portion after :
            splitline = line.split(":")[0]
            # Check group before adding it.
            if splitline != "root" and \
                splitline != "users" and \
                splitline != "nobody" and \
                splitline != "nogroup" and \
                    splitline != USERGROUP:
                # Add group to array.
                grparray.append(line.split(":")[0])
    # Add all detected groups to the current user.
    for group in grparray:
        print("Adding {0} to group {1}.".format(USERNAMEVAR, group))
        subprocess.run("usermod -aG {1} {0}".format(USERNAMEVAR, group), shell=True, check=True)
def AddUserToGroup(group, username=None):
    """Add a given user to a single given group."""
    # Detect user if not passed.
    if username is None:
        usertuple = getnormaluser()
        USERNAMEVAR = usertuple[0]
    else:
        USERNAMEVAR = username
    print("Adding {0} to group {1}.".format(USERNAMEVAR, group))
    subprocess.run("usermod -aG {1} {0}".format(USERNAMEVAR, group), shell=True, check=False)
def BackupSudoersFile(sudoersfile):
    """Backup the sudoers file before an operation."""
    # Backup the file if it exists.
    sudoersfile_backup = os.path.join(tempfile.gettempdir(), os.path.basename(sudoersfile))
    if os.path.isfile(sudoersfile):
        shutil.copy2(sudoersfile, sudoersfile_backup)
    return
def CheckRestoreSudoersFile(sudoersfile):
    """Check sudoers validity. Restore the sudoers file from a backup if the operation failed."""
    # Check if visudo reports successful configuration.
    status = subprocess.run('visudo -c', shell=True)
    sudoersfile_backup = os.path.join(tempfile.gettempdir(), os.path.basename(sudoersfile))
    if status.returncode != 0:
        # Restore the backup file if it exists.
        if os.path.isfile(sudoersfile_backup):
            print("Reverting sudoers change.")
            shutil.copy2(sudoersfile_backup, sudoersfile)
            os.chmod(sudoersfile, 0o440)
        else:
            print("ERROR: No backup file, can't revert sudoers change!")
    else:
        # Remove the backup file if everything was successful.
        if os.path.isfile(sudoersfile_backup):
            os.remove(sudoersfile_backup)
    return
def AddLineToSudoersFile(sudoersfile, line, overwrite=False):
    """Add a line to a sudoers file, and check if it is valid."""
    if os.path.isdir(os.path.dirname(sudoersfile)):
        if os.path.isfile(sudoersfile) and overwrite is True:
            print("Removing existing {0}".format(sudoersfile))
            os.remove(sudoersfile)
        BackupSudoersFile(sudoersfile)
        with open(sudoersfile, 'a') as sudoers_writefile:
            sudoers_writefile.write("{0}\n".format(line))
        os.chmod(sudoersfile, 0o440)
        CheckRestoreSudoersFile(sudoersfile)
    return
# Apt
def aptupdate():
    """Update apt sources"""
    subprocess.run("apt-get update", shell=True)
def aptdistupg():
    """Upgrade/Dist-Upgrade system using apt"""
    aptupdate()
    print("\nPerforming (dist)upgrade.")
    subprocess.run("apt-get upgrade -y", shell=True)
    subprocess.run("apt-get dist-upgrade -y", shell=True)
def aptinstall(aptapps):
    """Install application(s) using apt"""
    print("\nInstalling {0} using apt.".format(aptapps))
    if os.geteuid() is 0:
        subprocess.run("apt-get install -y {0}".format(aptapps), shell=True)
    else:
        subprocess.run("sudo apt-get install -y {0}".format(aptapps), shell=True)
def addppa(ppasource):
    """Add a ppa"""
    subprocess.run("add-apt-repository -y '{0}'".format(ppasource), shell=True)
    aptupdate()
def aptmark(aptapps, mark=True):
    """Set or unset apt-mark hold for packages. mark=True for holding, mark=False for unholding."""
    if mark is True:
        mark_text = "hold"
    else:
        mark_text = "unhold"
    subprocess.run("apt-mark {0} {1}".format(mark_text, aptapps), shell=True)
# DNF
def dnfupdate():
    """Update system"""
    print("\nPerforming system update.")
    subprocess.run("dnf update -y", shell=True)
def dnfinstall(dnfapps):
    """Install application(s) using dnf"""
    status = None
    print("\nInstalling {0} using dnf.".format(dnfapps))
    if os.geteuid() is 0:
        status = subprocess.run("dnf install -y {0}".format(dnfapps), shell=True).returncode
    else:
        status = subprocess.run("sudo dnf install -y {0}".format(dnfapps), shell=True).returncode
    return status
def rpmimport(keyurl):
    """Import a gpg key for rpm."""
    subprocess.run("rpm --import {0}".format(keyurl), shell=True, check=True)
# Zypper
def zpinstall(zpapps):
    """Install application(s) using zypper"""
    print("\nInstalling {0} using zypper.".format(zpapps))
    subprocess.run("zypper in -yl {0}".format(zpapps), shell=True)
# Flatpak
def flatpak_addremote(remotename, remoteurl):
    """Add a remote to flatpak."""
    if shutil.which("flatpak"):
        print("Installing remote {0}.".format(remotename))
        subprocess.run("{0}flatpak remote-add --if-not-exists {1} {2}".format(sudocmd(), remotename, remoteurl), shell=True)
def flatpak_install(remote, app):
    """Install application(s) using flatpak using the specified remote."""
    if shutil.which("flatpak"):
        print("\nInstalling {0} using flatpak using {1}.".format(app, remote))
        subprocess.run("{0}flatpak install -y {1} {2}".format(sudocmd(), remote, app), shell=True)
# Snap
def snap_install(app, classic=False):
    """Install application(s) using snap"""
    # Options
    snap_classic = ""
    if classic is True:
        snap_classic = "--classic"
    # Command
    if shutil.which("snap"):
        print("\nInstalling {0} using snap.".format(app))
        subprocess.run("{0}snap install {1} {2}".format(sudocmd(), snap_classic, app), shell=True)


if __name__ == '__main__':
    print("Warning, {0} is meant to be imported by a python script.".format(__file__))
