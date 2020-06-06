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

# Get user information.
USERNAMEVAR, USERGROUP, USERHOME = CFunc.getnormaluser()

# Get arguments
parser = argparse.ArgumentParser(description='Install Windows shell configuration.')

# Save arguments.
args = parser.parse_args()


### Powershell Configuration ###
# Get powershell command
powershell_cmd = "pwsh.exe"
powershell_cmd_fullpath = shutil.which(powershell_cmd)
# Install powershell modules
print("Install powershell modules.")
subprocess.run("""Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name 'posh-git' -AllowClobber
Install-Module -Name 'oh-my-posh' -AllowClobber
Install-Module -Name 'Get-ChildItemColor' -AllowClobber
""", shell=True, check=True, executable=powershell_cmd_fullpath)

# Install powershell profile
powershell_profile_script = CFunc.subpout('{0} -c "echo $PROFILE"'.format(powershell_cmd))
powershell_profile_folder = os.path.dirname(powershell_profile_script)

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

### Cygwin ###
# Check if cygwin is installed already.
cygwin_bash_cmd = os.path.join("C:", "cygwin64", "bin", "bash.exe")
if os.path.isfile(cygwin_bash_cmd):
    # Install apt-cyg
    subprocess.run("""cd ~/Documents
    git clone https://github.com/kou1okada/apt-cyg.git
    ln -s "$(realpath apt-cyg/apt-cyg)" /usr/local/bin/
    ln -s "$(realpath apt-cyg/apt-cyg)" /usr/local/bin/apt
    """, shell=True, check=True, executable=cygwin_bash_cmd)

    # Install required packages
    subprocess.run("apt-cyg -X install gnupg", shell=True, check=True, executable=cygwin_bash_cmd)
