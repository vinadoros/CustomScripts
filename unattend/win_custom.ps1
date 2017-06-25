$temppath = "C:\Windows\Temp"

# Power customizations
powercfg /hibernate off
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
powercfg -Change -monitor-timeout-ac 0
powercfg -Change -monitor-timeout-dc 0

# Chocolatey section
echo "Installing Chocolatey"
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
echo "Installing Chocolatey packages"
choco upgrade -y dotnet4.6.2 powershell
choco upgrade -y googlechrome javaruntime notepadplusplus git tortoisegit ccleaner putty chocolateygui conemu visualstudiocode winmerge libreoffice sumatrapdf pdfcreator 7zip
# Install for Windows 8 or above.
if ([Environment]::OSVersion.Version.Major -ge 8){
  choco upgrade -y classic-shell
}
# Install for lower than Windows 8
#if ([Environment]::OSVersion.Version.Major -lt 8){
#  choco upgrade -y wincdemu
#}

# Get Ninite
#echo "Getting ninite"
#$url = "https://ninite.com/.net4.6.2-7zip-chrome-classicstart-java8-libreoffice-notepadplusplus-pdfcreator-sumatrapdf-vscode-winmerge/ninite.exe"
#$ninitefile = "$ENV:UserProfile\Desktop\ninite.exe"
#(New-Object System.Net.WebClient).DownloadFile($url, $ninitefile)

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

# Set system clock to UTC
#write-host "Setting up NTP..."
#W32tm /register
#start-service w32time
#w32tm /config /manualpeerlist:uk.pool.ntp.org
#restart-service w32time
#Set-Service W32Time -StartupType Automatic
#sc triggerinfo w32time start/networkon stop/networkoff
#sc config W32Time start=auto

# Disable telemetry
#New-ItemProperty -Path Registry::HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection -Name AllowTelemetry -Value 0 -Force -ErrorAction SilentlyContinue | Out-Null
#Stop-Service diagtrack
#Set-Service diagtrack -startuptype disabled
#Stop-Service dmwappushsvc
#Set-Service dmwappushsvc -startuptype disabled

exit 0
