#!/usr/bin/env python3

# Python includes.
import os
import grp
import json
import pwd
import sys
import subprocess
import shutil
import stat
import urllib.request

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR=sys.path[0]

# Exit if not root.
if not os.geteuid() == 0:
    sys.exit("\nError: Please run this script as root.\n")

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
# Note: This folder is the root home folder if this script is run as root.
ROOTHOME=os.path.expanduser("~")
USERHOME=os.path.expanduser("/home/"+USERNAMEVAR)

# Ensure that certain commands exist.
cmdcheck = ["gpg","pacman","makepkg"]
for cmd in cmdcheck:
    if not shutil.which(cmd):
        sys.exit("\nError, ensure command {0} is installed.".format(cmd))

# Variables
BUILDFOLDER="/var/tmp"

# Functions
def aurbuild(package_name):
    os.chdir(BUILDFOLDER)
    # Get the filename from the URL.
    url = "https://aur.archlinux.org/cgit/aur.git/snapshot/{0}.tar.gz".format(package_name)
    fileinfo = urllib.parse.urlparse(url)
    filename = urllib.parse.unquote(os.path.basename(fileinfo.path))
    # Get the file.
    urllib.request.urlretrieve(url, filename)

    # Extract the file.
    shutil.unpack_archive(filename, BUILDFOLDER)
    AURFOLDER=BUILDFOLDER+"/"+package_name

    subprocess.run("""
    chmod a+rwx -R {0}
    cd {0}
    su {2} -s /bin/bash -c 'makepkg --noconfirm -A -s'
    pacman -U --noconfirm ./{1}-*.pkg.tar.xz
""".format(AURFOLDER, package_name, USERNAMEVAR), shell=True)

    # Cleanup
    os.chdir(BUILDFOLDER)
    if os.path.isdir(AURFOLDER):
        shutil.rmtree(AURFOLDER)
    os.remove(BUILDFOLDER+"/"+filename)
    return


# Edit sudoers.
with open('/etc/sudoers') as sudoers_file:
    sudoers_lines = sudoers_file.read()
if not "{0} ALL=(ALL) NOPASSWD: {1}".format(USERNAMEVAR, shutil.which("pacman")) in sudoers_lines:
    print("Editing sudoers file.")
    # Backup sudoers
    shutil.copy2("/etc/sudoers", "/etc/sudoers.bak")
    # Append text to sudoers.
    with open('/etc/sudoers', 'a') as sudoers_writefile:
        sudoers_writefile.write("""

# Allow user to run pacman without password (for Yaourt/makepkg).
{0} ALL=(ALL) NOPASSWD: {1}
{0} ALL=(ALL) NOPASSWD: {2}
""".format(USERNAMEVAR, shutil.which("pacman"), shutil.which("cp")))
    status = subprocess.run('visudo -c', shell=True)
    if status.returncode is not 0:
        print("Visudo status not 0, restoring sudoers file.")
        os.remove("/etc/sudoers")
        shutil.move("/etc/sudoers.bak", "/etc/sudoers")
    else:
        os.remove("/etc/sudoers.bak")
else:
    print("Sudoers already modified.")


# Set up GPG.
# Make sure .gnupg folder exists
if not os.path.isdir("/root/.gnupg"):
    print("Creating /root/.gnupg folder.")
    os.mkdir("/root/.gnupg")
if not os.path.isdir("{0}/.gnupg".format(USERHOME)):
    print("Creating {0}/.gnupg folder.".format(USERHOME))
    subprocess.run("""
# Set gnupg to auto-retrive keys. This is needed for some aur packages.
su {0} -s /bin/bash <<'EOL'
	gpg --list-keys
	# Have gnupg autoretrieve keys.
	if [ -f ~/.gnupg/gpg.conf ]; then
		sed -i 's/#keyserver-options auto-key-retrieve/keyserver-options auto-key-retrieve/g' ~/.gnupg/gpg.conf
	fi
EOL
""".format(USERNAMEVAR), shell=True)

# Ensure base and base-devel are present.
subprocess.run("pacman -Syu --needed --noconfirm base base-devel", shell=True)
# Build Yaourt
aurbuild("package-query")
aurbuild("yaourt")

# Yaourt config
# URL: https://www.archlinux.fr/man/yaourtrc.5.html
# Place all built packages in pacman cache folder.
with open('/etc/yaourtrc') as yaourtrc_file:
    yaourtrc_lines = yaourtrc_file.read()
if not "\nEXPORT=2" in yaourtrc_lines:
    print("Adding EXPORT=2 to yaourtrc file.")
    with open('/etc/yaourtrc', 'a') as yaourtrc_writefile:
        yaourtrc_writefile.write("\nEXPORT=2")

# Install powerpill
subprocess.run("su {0} -s /bin/bash -c 'gpg --recv-keys 1D1F0DC78F173680; yaourt -Syua --needed --noconfirm powerpill'".format(USERNAMEVAR), shell=True)
# Restore original powerpill configuration if it exists.
# if os.path.isfile("/etc/powerpill/powerpill.json.bak"):
#     os.remove("/etc/powerpill/powerpill.json")
#     shutil.move("/etc/powerpill/powerpill.json.bak", "/etc/powerpill/powerpill.json")
# Read the existing powerpill json.
with open('/etc/powerpill/powerpill.json') as powerpill_json:
    powerpill_data = json.load(powerpill_json)
# Add flags to powerpill config.
if not "--quiet" in powerpill_data["aria2"]["args"]:
    powerpill_data["aria2"]["args"].append("--quiet")
# Backup the existing powerpill configuration.
# shutil.move("/etc/powerpill/powerpill.json", "/etc/powerpill/powerpill.json.bak")
# Write the new powerpill json file.
with open('/etc/powerpill/powerpill.json', 'w') as powerpill_json_wr:
    json.dump(powerpill_data, powerpill_json_wr, indent=2)

# Configure yaourt to use powerpill for pacman operations
if not '\nPACMAN="powerpill"' in yaourtrc_lines:
    print('Adding PACMAN="powerpill" to yaourtrc file.')
    with open('/etc/yaourtrc', 'a') as yaourtrc_writefile:
        yaourtrc_writefile.write('\nPACMAN="powerpill"')
