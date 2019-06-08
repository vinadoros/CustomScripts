#!/usr/bin/env python3
"""Powershell configuration."""

# Python includes.
import argparse
import os
import shutil
import subprocess
import sys
# Custom includes
import CFunc

print("Running {0}".format(__file__))

# Folder of this script
SCRIPTDIR = sys.path[0]

# Get powershell command
powershell_cmd = shutil.which("powershell.exe")

# Get user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()

# Get arguments
parser = argparse.ArgumentParser(description='Install Powershell configuration.')

# Save arguments.
args = parser.parse_args()


# Install powershell modules
print("Install powershell modules.")
subprocess.run("""Install-PackageProvider -Name NuGet -RequiredVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name 'posh-git'
Install-Module -Name 'oh-my-posh'
Install-Module -Name 'Get-ChildItemColor'
""", shell=True, executable=powershell_cmd)

# Install powershell profile
powershell_profile_folder = os.path.join(USERHOME, "Documents", "WindowsPowerShell")
powershell_profile_script = os.path.join(powershell_profile_folder, "Microsoft.PowerShell_profile.ps1")
powershell_profile_text = """# Ensure that Get-ChildItemColor is loaded
Import-Module Get-ChildItemColor

# Set l and ls alias to use the new Get-ChildItemColor cmdlets
Set-Alias la Get-ChildItemColor -Option AllScope
Set-Alias ls Get-ChildItemColorFormatWide -Option AllScope

# Helper function to show Unicode character
function U
{
    param
    (
        [int] $Code
    )

    if ((0 -le $Code) -and ($Code -le 0xFFFF))
    {
        return [char] $Code
    }

    if ((0x10000 -le $Code) -and ($Code -le 0x10FFFF))
    {
        return [char]::ConvertFromUtf32($Code)
    }

    throw "Invalid character code $Code"
}

# Ensure posh-git is loaded
Import-Module -Name posh-git

# Ensure oh-my-posh is loaded
Import-Module -Name oh-my-posh

# Default the prompt to agnoster oh-my-posh theme
Set-Theme agnoster
"""
os.makedirs(powershell_profile_folder, exist_ok=True)
with open(powershell_profile_script, 'w') as powershell_profile_script_handle:
    powershell_profile_script_handle.write(powershell_profile_text)
