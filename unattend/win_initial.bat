@ECHO OFF
echo Set Execution Policy 64 Bit
cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
echo Set Execution Policy 32 Bit
C:\Windows\SysWOW64\cmd.exe /c powershell -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

REM Add IPv4 dns for virtual machines
netsh interface ipv4 add dnsserver "Ethernet" address=1.1.1.1 index=1
REM Same for Windows 7
netsh interface ipv4 add dnsserver "Local Area Network" address=1.1.1.1 index=1

REM Install Chocolatey
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
"%ALLUSERSPROFILE%\chocolatey\bin\choco.exe" upgrade -y dotnetfx powershell
