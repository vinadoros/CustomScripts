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
apm_native = "apm"
apm_flatpak = "flatpak run --command=apm io.atom.Atom"
apm_snap = "snap run atom.apm"
if shutil.which("apm"):
    print("Detected native apm command.")
    apm_cmd = apm_native
    atom_userconfigfolder = os.path.join(userhome, ".atom")
    atom_userconfig = os.path.join(atom_userconfigfolder, "config.cson")
elif subprocess.run(apm_snap, shell=True).returncode is 0:
    print("Detected snap apm command.")
    apm_cmd = apm_snap
    atom_userconfigfolder = os.path.join(userhome, ".atom")
    atom_userconfig = os.path.join(atom_userconfigfolder, "config.cson")
elif subprocess.run(apm_flatpak, shell=True).returncode is 0:
    print("Detected flatpak apm command.")
    apm_cmd = apm_flatpak
    atom_userconfigfolder = os.path.join(userhome, ".var", "app", "io.atom.Atom", "data")
    atom_userconfig = os.path.join(atom_userconfigfolder, "config.cson")
else:
    sys.exit("\nERROR: atom/apm command not found. Exiting.")

### Functions ###
def atom_ins(extension):
    """Install an extension"""
    subprocess.run("{0} install {1}".format(apm_cmd, extension), shell=True)


### Distro Specific Packages ###
if shutil.which("dnf"):
    CFunc.dnfinstall("ShellCheck python3-jedi")
elif shutil.which("apt-get"):
    CFunc.aptinstall("shellcheck python3-jedi python3-pip")
elif shutil.which("zypper"):
    subprocess.run("""	sudo zypper ar -f http://download.opensuse.org/repositories/devel:/languages:/python3/openSUSE_Tumbleweed/ languages-python3
sudo zypper ar -f http://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Tumbleweed/ languages-python
sudo zypper --non-interactive --gpg-auto-import-keys refresh
sudo zypper in -yl python3-jedi ShellCheck""", shell=True)

### Detect Windows Commands ###
if CFunc.is_windows() is True:
    sudocmd = ""
    pipcmd = "pip"
else:
    sudocmd = "sudo -H "
    pipcmd = "pip3"
### Language Specific packages ###
if shutil.which("gem"):
    print("Installing ruby gems.")
    subprocess.run("sudo -H gem install rails_best_practices", shell=True)
else:
    print("Ruby/gem not detected. Not installing ruby gems.")
if shutil.which(pipcmd):
    print("Installing python dependencies.")
    subprocess.run("{0}{1} install flake8".format(sudocmd, pipcmd), shell=True)
else:
    print("{0} not found. Not install python packages.".format(pipcmd))


### Extensions ###
print("\nInstalling Atom extensions.")
# Python plugins
atom_ins("autocomplete-python")
# Git plugins
atom_ins("git-plus git-time-machine")
# Sublime column editing
atom_ins("sublime-style-column-selection")
# File types
atom_ins("file-types")
# Split diff
atom_ins("split-diff")

### Extensions which require external packages ###
# Linting
atom_ins("linter linter-ui-default intentions busy-signal")
# Python
atom_ins("autocomplete-python linter-flake8")
# Ruby and Rails
atom_ins("linter-ruby linter-rails-best-practices")
# Shell
atom_ins("linter-shellcheck")
# Php
atom_ins("linter-php")
# C
atom_ins("linter-gcc")
# Powershell
atom_ins("language-powershell")
# Hardware languages
atom_ins("language-vhdl language-verilog")
# Docker
atom_ins("language-docker")

### Configuration ###
# Write cson file.
file_cson_text = '''"*":
  core:
    telemetryConsent: "no"
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
'''
if shutil.which("flake8"):
    file_cson_text += '''  "linter-flake8":
    ignoreErrorCodes: [
      "E501"
      "E302"
      "E266"
    ]
'''.format(flakepath=shutil.which("flake8"))
print("Writing {0}.".format(atom_userconfig))
with open(atom_userconfig, 'w') as file_cson_wr:
    file_cson_wr.write(file_cson_text)
