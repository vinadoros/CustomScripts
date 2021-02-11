#!/usr/bin/env python3
"""Install Atom extensions and configuration."""

# Python includes.
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Get user details.
usernamevar, usergroup, userhome = CFunc.getnormaluser()

# Exit if root.
CFunc.is_root(False)

# Check for apm command.
apm_native = ["apm"]
apm_flatpak = ["flatpak", "run", "--command=apm", "io.atom.Atom"]
if shutil.which("apm"):
    print("Detected native apm command.")
    apm_cmd = apm_native
    atom_userconfigfolder = os.path.join(userhome, ".atom")
    atom_userconfig = os.path.join(atom_userconfigfolder, "config.cson")
    if CFunc.is_windows() is True:
        pipcmd = ["pip"]
    elif shutil.which("pip3"):
        pipcmd = ["pip3"]
    else:
        pipcmd = None
elif subprocess.run(apm_flatpak, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
    print("Detected flatpak apm command.")
    apm_cmd = apm_flatpak
    pipcmd = ["flatpak", "run", "--command=pip3", "io.atom.Atom"]
    atom_userconfigfolder = os.path.join(userhome, ".var", "app", "io.atom.Atom", "data")
    atom_userconfig = os.path.join(atom_userconfigfolder, "config.cson")
else:
    sys.exit("\nERROR: atom/apm command not found. Exiting.")


### Functions ###
def atom_ins(extension):
    """Install an extension"""
    subprocess.run(apm_cmd + ["install", extension], check=False)


### Distro Specific Packages ###
if shutil.which("dnf"):
    CFunc.dnfinstall("ShellCheck")
elif shutil.which("apt-get"):
    CFunc.aptinstall("shellcheck python3-pip")

### Language Specific packages ###
if pipcmd:
    print("Installing python dependencies.")
    subprocess.run(pipcmd + ["install", "flake8"], check=False)
else:
    print("{0} not found. Not install python packages.".format(pipcmd))


### Extensions ###
print("\nInstalling Atom extensions.")
# Python plugins
atom_ins("autocomplete-python")
# Git plugins
atom_ins("git-plus")
atom_ins("git-time-machine")
# Sublime column editing
atom_ins("sublime-style-column-selection")
# File types
atom_ins("file-types")
# Split diff
atom_ins("split-diff")

### Extensions which require external packages ###
# Linting
atom_ins("linter")
atom_ins("busy-signal")
atom_ins("linter-ui-default")
atom_ins("intentions")
# Python
atom_ins("autocomplete-python")
atom_ins("linter-flake8")
# Shell
atom_ins("linter-shellcheck")
# C
atom_ins("linter-gcc")
# Powershell
atom_ins("language-powershell")
# Docker
atom_ins("language-docker")

### Configuration ###
# Write cson file.
file_cson_text = '''"*":
  core:
    telemetryConsent: "no"
  "autocomplete-python":
    useKite: false
  editor:
    showIndentGuide: true
    showInvisibles: true
    softWrap: true
  welcome:
    showOnStartup: false
  "file-types":
    "Dockerfile.*$": "source.dockerfile"
  "split-diff":
    muteNotifications: true
    turnOffSoftWrap: true
  "linter-flake8":
    ignoreErrorCodes: [
      "E501"
      "E302"
      "E266"
    ]
'''
print("Writing {0}.".format(atom_userconfig))
with open(atom_userconfig, 'w') as file_cson_wr:
    file_cson_wr.write(file_cson_text)
