
# Source Fcns
if (-Not $PSScriptRoot) { $PSScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition) }
if (Test-Path "$PSScriptRoot\Win-provision.ps1") { . $PSScriptRoot\Win-provision.ps1; Fcn-SourceChocolatey }


# Ensure git is installed.
choco install -y git

# Variables have been set in the provision script.

cd $env:USERPROFILE
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
