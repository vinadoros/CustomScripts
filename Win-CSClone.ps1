
### Functions ###
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


# Set root path for CS clone.
$CSRootPath = $env:USERPROFILE
# Set repo user and repo name.
$RepoUser = "ramesh45345"
$RepoName = "CustomScripts"
$Repo = "$RepoUser/$RepoName"
$RepoLocalPath = "$CSRootPath\$RepoName"

if (-Not (Test-Path "$RepoLocalPath")) {
  git clone "https://github.com/$Repo.git"
}
cd "$RepoLocalPath"
# If ssh configuration exists, use updated remote url.
if (Test-Path "$env:USERPROFILE\.ssh\config"){
  git config remote.origin.url "git@gitserv:$Repo.git"
} else {
  git config remote.origin.url "https://github.com/$Repo.git"
}

git pull

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
