# Provision script for unattended installs or packer.

# Check if dot sourced.
$isDotSourced = $MyInvocation.InvocationName -eq '.' -or $MyInvocation.Line -eq ''


### Variables ###
$CSRootPath = $env:USERPROFILE
$RepoUser = "ramesh45345"
$RepoName = "CustomScripts"
$Repo = "$RepoUser/$RepoName"
$RepoLocalPath = "$CSRootPath\$RepoName"
# Check if Virtual Machine
$VMstring = gwmi -q "select * from win32_computersystem"
if ( $VMstring.Model -imatch "vmware" ) {
  $IsVM = $true
} elseif ( $VMstring.Model -imatch "virtualbox" ) {
  $IsVM = $true
} else {
  $IsVM = $false
}
# Test for Server Core.
# Basically see if exlorer.exe is present.
# https://serverfault.com/questions/529124/identify-windows-2012-server-core#529131
if (Test-Path "$env:windir\explorer.exe"){
  $core = $false
} else {
  $core = $true
}


### Functions ###

# Install chocolatey
function Fcn-InstallChocolatey {
  iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  # Ensure powershell is updated for Windows 7.
  if ([Environment]::OSVersion.Version.Major -lt 8){
    choco upgrade -y dotnet4.7 powershell
  }
}

# Add path to environment.
# https://stackoverflow.com/questions/714877/setting-windows-powershell-path-variable#1333717
# https://gist.github.com/mkropat/c1226e0cc2ca941b23a9
function Add-EnvPath {
    param(
        [Parameter(Mandatory=$true)]
        [string] $Path,

        [ValidateSet('Machine', 'User', 'Session')]
        [string] $Container = 'Session'
    )

    if ($Container -ne 'Session') {
        $containerMapping = @{
            Machine = [EnvironmentVariableTarget]::Machine
            User = [EnvironmentVariableTarget]::User
        }
        $containerType = $containerMapping[$Container]

        $persistedPaths = [Environment]::GetEnvironmentVariable('Path', $containerType) -split ';'
        if ($persistedPaths -notcontains $Path) {
            $persistedPaths = $persistedPaths + $Path | where { $_ }
            [Environment]::SetEnvironmentVariable('Path', $persistedPaths -join ';', $containerType)
        }
    }

    $envPaths = $env:Path -split ';'
    if ($envPaths -notcontains $Path) {
        $envPaths = $envPaths + $Path | where { $_ }
        $env:Path = $envPaths -join ';'
    }
}

# Rudimentary CS Clone.
function Fcn-CSClone {
  # Ensure git is installed.
  choco install -y git
  # Git executable
  $gitcmdpath = "C:\Program Files\Git\bin"

  cd $env:USERPROFILE
  if (-Not (Test-Path "$RepoLocalPath")) {
    Start-Process -Wait "$gitcmdpath\git.exe" -ArgumentList "clone","https://github.com/$Repo.git"
  }
  cd "$RepoLocalPath"
  # If ssh configuration exists, use updated remote url.
  if (Test-Path "$env:USERPROFILE\.ssh\config"){
    Start-Process -Wait "$gitcmdpath\git.exe" -ArgumentList "config","remote.origin.url","git@gitserv:$Repo.git"
  } else {
    Start-Process -Wait "$gitcmdpath\git.exe" -ArgumentList "config","remote.origin.url","https://github.com/$Repo.git"
  }

  Start-Process -Wait "$gitcmdpath\git.exe" -ArgumentList "pull"

  # Add CS to path.
  Add-EnvPath "$RepoLocalPath" 'User'

  # Create scheduled task.
  # https://stackoverflow.com/questions/23953926/how-to-execute-a-powershell-script-automatically-using-windows-task-scheduler

  $taskName = "csupdate"
  $taskExists = Get-ScheduledTask | Where-Object {$_.TaskName -like $taskName }

  if($taskExists) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  }

  $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-ExecutionPolicy Bypass -WindowStyle Hidden -command "&git pull"' -WorkingDirectory $RepoLocalPath
  $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSPan -Hours 1)
  # This task is registered as a normal user for now. By default, it will pop up a small window briefly, and will only run if the user is logged in. To get rid of the window, enable the "Run whether user is logged on or not" option in Task Scheduler for this task.
  # https://stackoverflow.com/questions/1802127/how-to-run-a-powershell-script-without-displaying-a-window#1802836
  Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "csupdate" -Description "Hourly Update of $RepoName" -User $env:UserName
}

# Software Function
function Fcn-Software {
  # Required Basics
  choco upgrade -y dotnet4.7 powershell
  # Install universal apps
  choco upgrade -y 7zip
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
    choco upgrade -y googlechrome notepadplusplus tortoisegit ccleaner putty chocolateygui conemu visualstudiocode winmerge libreoffice sumatrapdf nomacs javaruntime
    # Tablacus
    Fcn-Tablacus
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

  # Non-vm software
  if ( $IsVM -eq $false ) {
    # Install packer
    choco upgrade -y packer --version 1.1.1 --force
    # Install python dependancies
    pip install passlib
  }
}

# Enable Hyper-V
function Fcn-HypervEn {
  # Windows 10
  Enable-WindowsOptionalFeature -Online -FeatureName:Microsoft-Hyper-V -All -NoRestart
  # Windows Server
  Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
}

# Disable Hyper-V
function Fcn-HypervDis {
  # Windows 10
  Disable-WindowsOptionalFeature -Online -FeatureName:Microsoft-Hyper-V -NoRestart
  # Windows Server
  Uninstall-WindowsFeature -Name Hyper-V -IncludeManagementTools
}

# Tablacus Function
function Fcn-Tablacus {
  # Install/upgrade Tablacus
  choco upgrade -y tablacus

  # Tablacus configuration
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
}

# Disable Windows 10 Tracking
function Fcn-Disable10Tracking {
  # Get Release version
  $diswintrack_version = "3.1.2"
  $diswintrack_url = "https://github.com/10se1ucgo/DisableWinTracking/releases/download/v$diswintrack_version/dwt-$diswintrack_version-cp27-win_x86.zip"
  $diswintrack_localzip = "C:\Windows\Temp\dwt.zip"
  $diswintrack_localfld = "C:\Windows\Temp\dwt"
  # Download Release
  Invoke-WebRequest -Uri $diswintrack_url -OutFile $diswintrack_localzip
  # Extract
  Start-Process -Wait "C:\Program Files\7-Zip\7z.exe" -ArgumentList "x","$diswintrack_localzip","-o$diswintrack_localfld"
  # Run
  if ((Test-Path "$diswintrack_localfld\DisableWinTracking.exe") -And ([Environment]::OSVersion.Version.Major -ge 10)) {
    echo "Disable Windows 10 Tracking"
    Start-Process -Wait "$diswintrack_localfld\DisableWinTracking.exe" -ArgumentList "-silent"
  }

  # Clean up
  Remove-Item -Recurse -Force $diswintrack_localfld
  Remove-Item -Recurse -Force $diswintrack_localzip
}

# Customize Function
function Fcn-Customize {
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
}

# Remove Windows Features
function Fcn-Remove {
  # Remove windows defender from core or VMs.
  if ( $core -eq $true -Or $IsVM -eq $true ) {
    # Windows Server
    Uninstall-WindowsFeature Windows-Defender
  }
}

### Begin Code ###
if (-Not $isDotSourced) {
  echo "Running provision script."
  Fcn-InstallChocolatey
  Fcn-CSClone
  Fcn-Software
  Fcn-Customize
  Fcn-Remove
}
