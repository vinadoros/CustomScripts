#!/usr/bin/env python3
"""Install VS Code extensions and configuration."""

# Python includes.
import json
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
vscode_userconfigfolder = userhome + "/.config/Code/User"
vscode_userconfig = vscode_userconfigfolder + "/settings.json"

# Exit if root.
if os.geteuid() is 0:
    sys.exit("\nError: Please run this script as a normal user.\n")

# Check if installed.
if not shutil.which("code"):
    sys.exit("\nERROR: code command not found. Exiting.")


### Functions ###
def ce_ins(extension):
    """Install an extension"""
    subprocess.run("code --install-extension {0}".format(extension), shell=True)


### Extensions ###
ce_ins("ms-python.python")
ce_ins("ms-vscode.cpptools")
ce_ins("PeterJausovec.vscode-docker")


### Configuration ###
data = {}
data["editor.renderWhitespace"] = "all"
data["editor.wordWrap"] = "on"
data["python.pythonPath"] = "python3"
data["python.linting.maxNumberOfProblems"] = 500
# data["python.linting.pylintArgs"] = ["--disable="]
data["python.linting.pylamaEnabled"] = True
data["python.linting.pylamaArgs"] = ["-i", "E501,E266"]
# data["python.linting.pylintPath"] = "{0}".format(shutil.which("pylint"))

# Print the json data for debugging purposes.
# print(json.dumps(data, indent=2))

# Write json file.
print("Writing {0}.".format(vscode_userconfig))
with open(vscode_userconfig, 'w') as file_json_wr:
    json.dump(data, file_json_wr, indent=2)
