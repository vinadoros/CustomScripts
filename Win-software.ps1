
# https://stackoverflow.com/questions/2157554/how-to-handle-command-line-arguments-in-powershell
param (
   [bool]$core = $false
)

# Source Fcns
if (-Not $PSScriptRoot) { $PSScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition) }
# Install chocolatey
if (Test-Path "$PSScriptRoot\Win-provision.ps1") { . $PSScriptRoot\Win-provision.ps1; Fcn-InstallChocolatey }

# Required Basics
choco upgrade -y dotnet4.7 powershell
# Install universal apps
choco update -y 7zip
# Libraries
choco upgrade -y vcredist-all git python

# Install VM Tools
if ( $IsVM -eq $true ) {
  # Handle VMTools
  $temppath = "C:\Windows\Temp"
  $winiso = "C:\Windows\Temp\windows.iso"
  $vmfolder = "$temppath\vmfolder"
  if (Test-Path $winiso) {
    echo "Installing VM Tools"
    Start-Process -Wait "C:\Program Files\7-Zip\7z.exe" -ArgumentList "x","$winiso","-o$vmfolder"

    if (Test-Path "$vmfolder\setup64.exe") {
      echo "Installing VMWare tools"
      Start-Process -Wait "$vmfolder\setup64.exe" -ArgumentList "/s","/v/qr","REBOOT=R"
    }

    if (Test-Path "$vmfolder\VBoxWindowsAdditions.exe") {
      echo "Installing VMWare tools"
      Start-Process -Wait "$vmfolder\cert\VBoxCertUtil.exe" -ArgumentList "add-trusted-publisher","$vmfolder\cert\vbox-sha1.cer" | Out-Null
      Start-Process -Wait "$vmfolder\VBoxWindowsAdditions.exe" -ArgumentList "/S"
    }

    # Clean up vmtools
    echo "Cleaning up VMTools"
    Remove-Item -Recurse -Force $winiso
    Remove-Item -Recurse -Force $vmfolder
  }
}

# Install packages not for core.
if ( $core -eq $false ) {
  echo "Installing Desktop Apps"
  # GUI Apps
  choco upgrade -y googlechrome notepadplusplus tortoisegit ccleaner putty chocolateygui conemu visualstudiocode winmerge libreoffice sumatrapdf javaruntime
  # Tablacus
  cd $PSScriptRoot
  .\Win-tablacus.ps1
  # Install for Windows 8 or above.
  if ([Environment]::OSVersion.Version.Major -ge 8){
    choco upgrade -y classic-shell ShutUp10
  }
  # Install for lower than Windows 8
  if ([Environment]::OSVersion.Version.Major -lt 8){
    choco upgrade -y ie11
  }
}

# Chocolatey Configuration
choco feature enable -n allowGlobalConfirmation


if ( $IsVM -eq $false ) {
  # Install packer
  choco upgrade -y packer --version 1.1.1 --force
  # Install python and dependancies
  choco upgrade -y python
  pip install passlib
  # Enable Hyper-V
  #Enable-WindowsOptionalFeature -Online -FeatureName:Microsoft-Hyper-V -All -NoRestart
}
