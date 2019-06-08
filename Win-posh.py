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
powershell_profile_text = """<#
.SYNOPSIS
  Powershell Profile.
#>
 
# Ensure that Get-ChildItemColor is loaded
Import-Module Get-ChildItemColor

# Ensure posh-git is loaded
Import-Module -Name posh-git

# Ensure oh-my-posh is loaded
Import-Module -Name oh-my-posh

# Default the prompt to agnoster oh-my-posh theme
Set-Theme agnoster


### Functions ###
Function Format-FileSize() {
    Param ([int]$size)
    If     ($size -gt 1TB) {[string]::Format("{0:0.00} TB", $size / 1TB)}
    ElseIf ($size -gt 1GB) {[string]::Format("{0:0.00} GB", $size / 1GB)}
    ElseIf ($size -gt 1MB) {[string]::Format("{0:0.00} MB", $size / 1MB)}
    ElseIf ($size -gt 1KB) {[string]::Format("{0:0.00} kB", $size / 1KB)}
    ElseIf ($size -gt 0)   {[string]::Format("{0:0.00} B", $size)}
    Else                   {""}
}
Function Fcn-List-All {
    Get-ChildItemColor | Select-Object Mode, @{Name="Size";Expression={Format-FileSize($_.Length)}}, LastWriteTime, Name
}


### Aliases ###
# Set la and ls alias to use the new Get-ChildItemColor cmdlets
# Set-Alias -Name la -Value Fcn-List-All
Set-Alias l Get-ChildItemColor -option AllScope
Set-Alias la Get-ChildItemColor -option AllScope
Set-Alias ls Get-ChildItemColorFormatWide -Option AllScope

"""
os.makedirs(powershell_profile_folder, exist_ok=True)
with open(powershell_profile_script, 'w') as powershell_profile_script_handle:
    powershell_profile_script_handle.write(powershell_profile_text)
