$temppath = "C:\Windows\Temp"

# Chocolatey section
echo "Installing Chocolatey"
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
echo "Installing Chocolatey packages"
choco upgrade -y dotnet4.6.1 powershell
choco upgrade -y googlechrome jre8 notepadplusplus git tortoisegit ccleaner putty chocolateygui conemu visualstudiocode winmerge libreoffice sumatrapdf pdfcreator 7zip
# Install for Windows 8 or above.
if ([Environment]::OSVersion.Version.Major -ge 8){
  choco upgrade -y classic-shell
}
# Install for lower than Windows 8
#if ([Environment]::OSVersion.Version.Major -lt 8){
#  choco upgrade -y wincdemu
#}

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
