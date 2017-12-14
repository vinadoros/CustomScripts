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
usernamevar = os.getenv("USER")
usergroup, userhome = CFunc.getuserdetails(usernamevar)

### Variables ###
atom_userconfigfolder = userhome + "/.atom"
atom_userconfig = atom_userconfigfolder + "/config.cson"

# Exit if root.
if os.geteuid() is 0:
    sys.exit("\nError: Please run this script as a normal user.\n")

# Check if installed.
if not shutil.which("apm"):
    sys.exit("\nERROR: atom/apm command not found. Exiting.")


### Functions ###
def atom_ins(extension):
    """Install an extension"""
    subprocess.run("apm install {0}".format(extension), shell=True)


### Distro Specific Packages ###
if shutil.which("dnf"):
    CFunc.dnfinstall("ShellCheck python3-jedi")
elif shutil.which("apt-get"):
    CFunc.dnfinstall("shellcheck python3-jedi python3-pip")
elif shutil.which("zypper"):
    subprocess.run("""	sudo zypper ar -f http://download.opensuse.org/repositories/devel:/languages:/python3/openSUSE_Tumbleweed/ languages-python3
sudo zypper ar -f http://download.opensuse.org/repositories/devel:/languages:/python/openSUSE_Tumbleweed/ languages-python
sudo zypper --non-interactive --gpg-auto-import-keys refresh
sudo zypper in -yl python3-jedi ShellCheck python3-pylama python-pylama_pylint""", shell=True)


### Language Specific packages ###
if shutil.which("gem"):
    print("Installing ruby gems.")
    subprocess.run("sudo -H gem install rails_best_practices", shell=True)
else:
    print("Ruby/gem not detected. Not installing ruby gems.")
if shutil.which("pip3"):
    print("Installing python dependencies.")
    subprocess.run("sudo -H pip3 install pylama pylama-pylint", shell=True)
else:
    print("pip3 not found. Not install python packages.")


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
atom_ins("autocomplete-python linter-python")
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
atom_ins("language-docker docker")

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
'''
if shutil.which("pylama"):
    file_cson_text += '''  "linter-python":
    executablePath: "{pylamapath}"
    ignoreCodes: "C0301"
    lintTrigger: "File saved or modified"
    withPylint: true
'''.format(pylamapath=shutil.which("pylama"))
print("Writing {0}.".format(atom_userconfig))
with open(atom_userconfig, 'w') as file_cson_wr:
    file_cson_wr.write(file_cson_text)
