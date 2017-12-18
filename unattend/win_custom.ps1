$temppath = "C:\Windows\Temp"

# Check if Virtual Machine
$VMstring = gwmi -q "select * from win32_computersystem"
if ( $VMstring.Model -imatch "vmware" -Or $VMstring.Model -imatch "virtualbox" ) {
  $IsVM = $true
}
else {
  $IsVM = $false
}

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

# Chocolatey section
echo "Installing Chocolatey"
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
echo "Installing Chocolatey packages"
choco upgrade -y dotnet4.7 powershell
choco upgrade -y vcredist-all googlechrome javaruntime notepadplusplus git tortoisegit ccleaner putty chocolateygui conemu visualstudiocode winmerge libreoffice sumatrapdf 7zip tablacus
# Install for Windows 8 or above.
if ([Environment]::OSVersion.Version.Major -ge 8){
  choco upgrade -y classic-shell ShutUp10
}
# Install for lower than Windows 8
if ([Environment]::OSVersion.Version.Major -lt 8){
  choco upgrade -y ie11
}
# Chocolatey Configuration
choco feature enable -n allowGlobalConfirmation

# Tablacus
$pathtotablacus = "$env:PROGRAMDATA\chocolatey\lib\tablacus\tools\"
if(Test-Path -Path $pathtotablacus){
  # Set rwx everyone permissions for tablacus folder
  $Acl = Get-ACL $pathtotablacus
  $AccessRule= New-Object System.Security.AccessControl.FileSystemAccessRule("everyone","full","ContainerInherit,Objectinherit","none","Allow")
  $Acl.AddAccessRule($AccessRule)
  Set-Acl $pathtotablacus $Acl
  # Create shortcut for tablacus
  $WshShell = New-Object -comObject WScript.Shell
  $Shortcut = $WshShell.CreateShortcut("$env:PUBLIC\Desktop\Tablacus.lnk")
  $Shortcut.TargetPath = "$pathtotablacus\TE64.exe"
  $Shortcut.WorkingDirectory = "$pathtotablacus"
  $Shortcut.Save()
}

# Handle VMTools
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

exit 0
