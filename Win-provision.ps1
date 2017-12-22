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

### Functions ###

# Install chocolatey
function Fcn-InstallChocolatey {
  iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  # Ensure powershell is updated for Windows 7.
  if ([Environment]::OSVersion.Version.Major -lt 8){
    choco upgrade -y dotnet4.7 powershell
  }
}

# Source chocolatey if files exist.
function Fcn-SourceChocolatey {
  if (Test-Path "$env:ProgramData\chocolatey\helpers\functions\Update-SessionEnvironment.ps1"){
    . $env:ProgramData\chocolatey\helpers\functions\Write-FunctionCallLogMessage.ps1
    . $env:ProgramData\chocolatey\helpers\functions\Get-EnvironmentVariable.ps1
    . $env:ProgramData\chocolatey\helpers\functions\Get-EnvironmentVariableNames.ps1
    . $env:ProgramData\chocolatey\helpers\functions\Update-SessionEnvironment.ps1
    . $env:ProgramData\chocolatey\helpers\ChocolateyTabExpansion.ps1
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
function Fcn-InitialClone {
  cd $env:USERPROFILE
  if (-Not (Test-Path "$RepoLocalPath")) {
    git clone "https://github.com/$Repo.git"
  }
}

# Test for Server Core.
function Fcn-IsCore {
  # Basically see if exlorer.exe is present.
  # https://serverfault.com/questions/529124/identify-windows-2012-server-core#529131
  if (Test-Path "$env:windir\explorer.exe"){
    $core = $false
  } else {
    $core = $true
  }
  return $core
}


### Begin Code ###
if (-Not $isDotSourced) {
  echo "Running provision script."
  # Install Chocolatey.
  Fcn-InstallChocolatey
  # CS Clone
  Fcn-InitialClone
  cd $env:USERPROFILE\CustomScripts
  .\Win-CSClone.ps1
  if (Fcn-IsCore) {
    .\Win-software.ps1 -core $core
  } else {
    .\Win-software.ps1
  }
  .\Win-config.ps1
}
