$temppath = "C:\Windows\Temp"

# Install 7-Zip
echo "Installing 7-zip"
$url = "http://www.7-zip.org/a/7z1604-x64.msi"
$sevenfile = "$temppath\7z.msi"
(New-Object System.Net.WebClient).DownloadFile($url, $sevenfile)
Start-Process -Wait "$sevenfile" -ArgumentList "/qn","/passive"
Remove-Item -Recurse -Force $sevenfile

# Check if Windows 7
if ([Environment]::OSVersion.Version.Major -eq 6 -And [Environment]::OSVersion.Version.Minor -eq 1){
  echo "Windows 7 detected."
  # Install .net Framework 4.5.2 on Windows 7
  echo "Installing .net 4.5.2"
  $url = "https://download.microsoft.com/download/9/A/7/9A78F13F-FD62-4F6D-AB6B-1803508A9F56/51209.34209.03/web/NDP452-KB2901954-Web.exe"
  $netfile = "$temppath\NDP452-KB2901954-Web.exe"
  (New-Object System.Net.WebClient).DownloadFile($url, $netfile)
  Start-Process -Wait "$netfile" -ArgumentList /quiet
  Remove-Item -Recurse -Force $netfile

  # Check if Powershell is less than 4
  if ($PSVersionTable.PSVersion.Major -lt 4){
    # Install Powershell 5 on Windows 7
    echo "Installing Powershell 5"
    $url = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip"
    $psfile = "$temppath\Win7AndW2K8R2-KB3191566-x64.zip"
    (New-Object System.Net.WebClient).DownloadFile($url, $psfile)
    $psfolder = "$temppath\psfolder"
    Start-Process -Wait "C:\Program Files\7-Zip\7z.exe" -ArgumentList "x","$psfile","-o$psfolder"
    Start-Process -Wait "$psfolder\Win7AndW2K8R2-KB3191566-x64.msu" -ArgumentList /quiet,/norestart
    Remove-Item -Recurse -Force $psfolder
    Remove-Item -Recurse -Force $psfile
  }
}

# Get Ninite
echo "Getting ninite"
$url = "https://ninite.com/.net4.6.2-7zip-chrome-classicstart-java8-libreoffice-notepadplusplus-pdfcreator-sumatrapdf-vscode-winmerge/ninite.exe"
$ninitefile = "$ENV:UserProfile\Desktop\ninite.exe"
(New-Object System.Net.WebClient).DownloadFile($url, $ninitefile)

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

# Chocolatey section
echo "Installing Chocolatey"
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
echo "Installing Chocolatey packages"
choco upgrade -y googlechrome jre8 notepadplusplus git tortoisegit ccleaner putty chocolateygui conemu visualstudiocode winmerge libreoffice sumatrapdf pdfcreator
# Install for Windows 8 or above.
if ([Environment]::OSVersion.Version.Major -ge 8){
  choco upgrade -y classic-shell
}
# Install for lower than Windows 8
if ([Environment]::OSVersion.Version.Major -lt 8){
  choco upgrade -y wincdemu
}

# Windows customizations
echo "Extra Folder Options"
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowSuperHidden -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name ShowSuperHidden -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
New-ItemProperty -Path Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null
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

exit 0
