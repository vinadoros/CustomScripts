
# Source Fcns
if (-Not $PSScriptRoot) { $PSScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition) }
if (Test-Path "$PSScriptRoot\Win-provision.ps1") { . $PSScriptRoot\Win-provision.ps1; Fcn-SourceChocolatey }

### Variables ###

# Power customizations
if ( $IsVM -eq $true ) {
  # Set the High Performance mode for VMs.
  # powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
  powercfg -Change -monitor-timeout-ac 0
  powercfg -Change -monitor-timeout-dc 0
}
else {
  powercfg -Change -monitor-timeout-ac 10
  powercfg -Change -monitor-timeout-dc 10
}
# Set other timeouts (as listed in "powercfg /?" )
powercfg /hibernate off
powercfg -Change -disk-timeout-ac 0
powercfg -Change -disk-timeout-dc 0
powercfg -Change -standby-timeout-ac 0
powercfg -Change -standby-timeout-dc 0
powercfg -Change -hibernate-timeout-ac 0
powercfg -Change -hibernate-timeout-dc 0
# https://superuser.com/questions/874849/change-what-closing-the-lid-does-from-the-commandline
# Set the lid close to do nothing for high performance profile.
powercfg -setdcvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 000
powercfg -setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 000
# Set the lid close to do nothing for balanced profile.
powercfg -setdcvalueindex 381b4222-f694-41f0-9685-ff5bb260df2e 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 000
powercfg -setacvalueindex 381b4222-f694-41f0-9685-ff5bb260df2e 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 000


# Windows customizations
echo "Extra Folder Options"
# Show OS Files
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowSuperHidden -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
# Launch Windows Explorer in ThisPC
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
# Don't hide file extensions
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name HideFileExt -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
# Show hidden files
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name Hidden -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
# Display full paths
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name FullPath -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name FullPathAddress -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
echo "Hide Search bar"
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
echo "Set small icons for taskbar"
New-ItemProperty -Path Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarSmallIcons -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
echo "Show taskbar on multiple displays"
New-ItemProperty -Path Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarEnabled -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarMode -Value 2 -Force -ErrorAction SilentlyContinue | Out-Null
echo "Combine taskbar items only when full"
New-ItemProperty -Path Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarGlomLevel -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
# Remove people button
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name PeopleBand -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
# Enable quickedit in shells
New-ItemProperty -Path Registry::HKCU\Console -Name QuickEdit -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
# Set Control Panel Icon Size
echo "Control Panel icon changes"
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name AllItemsIconView -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel -Name StartupPage -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null

# Set pagefile
wmic computersystem set AutomaticManagedPagefile=False
wmic pagefileset delete
wmic pagefileset create name="$ENV:SystemDrive\pagefile.sys"
$PageFile = Get-WmiObject -Class Win32_PageFileSetting
$PageFile.InitialSize = 64
$PageFile.MaximumSize = 2048
$PageFile.Put()

# Disable thumbs.db on lower than Windows 8
if ([Environment]::OSVersion.Version.Major -lt 8){
  echo "Disable Thumbs.db"
  New-ItemProperty -Path Registry::HKCU\Software\Policies\Microsoft\Windows\Explorer -Name DisableThumbsDBOnNetworkFolders -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
  New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name DisableThumbnailCache -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
}

# Set EST as timezone
tzutil /s "Eastern Standard Time"
# Set system clock as UTC
New-ItemProperty -Path Registry::HKLM\System\CurrentControlSet\Control\TimeZoneInformation -Name RealTimeIsUniversal -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
