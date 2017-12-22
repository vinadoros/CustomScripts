
# Source Fcns
if (-Not $PSScriptRoot) { $PSScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition) }
if (Test-Path "$PSScriptRoot\Win-provision.ps1") { . $PSScriptRoot\Win-provision.ps1; Fcn-SourceChocolatey }

# https://stackoverflow.com/questions/41554300/how-to-run-retry-the-commands-multiple-times-in-try-block
$success = $false
$attempt = 10
while ($attempt -gt 0 -and -not $success){
  try{

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

    $success = $true
  } catch {
      echo "ERROR: Attempt $attempt failed."
      $attempt--
  }
}
