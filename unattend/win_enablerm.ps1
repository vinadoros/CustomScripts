# http://www.hurryupandwait.io/blog/fixing-winrm-firewall-exception-rule-not-working-when-internet-connection-type-is-set-to-public
# First set all networks to private, then enable winrm.
# Enable WinRM documentation:
# http://blog.petegoo.com/2016/05/10/packer-aws-windows/
# https://github.com/StefanScherer/packer-windows/blob/my/scripts/enable-winrm.ps1

# For Windows 7
if ([Environment]::OSVersion.Version.Major -lt 8){
  # Set networks to private.
  $networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}"))
  $connections = $networkListManager.GetNetworkConnections()
  # Set network location to Private for all networks
  $connections | % {$_.GetNetwork().SetCategory(1)}

  # Windows 7 does not have the SkipNetworkProfileCheck option
  # Enable powershell remoting.
  Enable-PSRemoting -Force
}
else {
  # For Windows 8 and above
  # Set networks to private.
  Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

  # Enable powershell remoting.
  Enable-PSRemoting -Force -SkipNetworkProfileCheck
}
