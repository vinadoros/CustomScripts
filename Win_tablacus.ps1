
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
