# http://www.hurryupandwait.io/blog/fixing-winrm-firewall-exception-rule-not-working-when-internet-connection-type-is-set-to-public
# First set all networks to private, then enable winrm.
# Enable WinRM documentation:
# http://blog.petegoo.com/2016/05/10/packer-aws-windows/
# https://github.com/StefanScherer/packer-windows/blob/my/scripts/enable-winrm.ps1

# For Windows 8 and above
# Set networks to private.
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

# Enable powershell remoting.
Enable-PSRemoting -Force -SkipNetworkProfileCheck

winrm quickconfig -q
winrm quickconfig -transport:http
winrm set winrm/config '@{MaxTimeoutms="1800000"}'
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="800"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/listener?Address=*+Transport=HTTP '@{Port="5985"}'
Restart-Service winrm