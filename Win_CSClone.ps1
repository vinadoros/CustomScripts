
# Set root path for CS clone.
$CSRootPath = $env:USERPROFILE
# Set repo user and repo name.
$RepoUser = "ramesh45345"
$RepoName = "CustomScripts"
$Repo = "$RepoUser/$RepoName"
$RepoLocalPath = "$CSRootPath/$RepoName"

if (-Not Test-Path "$RepoLocalPath") {
  git clone "https://github.com/$Repo.git"
}
cd "$RepoLocalPath"
git config remote.origin.url "https://github.com/$Repo.git"
git pull

# Add CS to path.
# https://stackoverflow.com/questions/714877/setting-windows-powershell-path-variable#1333717

# Create scheduled task.
# https://stackoverflow.com/questions/23953926/how-to-execute-a-powershell-script-automatically-using-windows-task-scheduler
#$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command "& {}"'
#$trigger =  New-ScheduledTaskTrigger -Daily -At 9am
#Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "{0}Update" -f $RepoName -Description "Hourly Update of $RepoName"
