:: Released under the GNU General Public License version 3+ by J2897.

@echo OFF
pushd "%~dp0"
setlocal
set "TITLE=Deploy Cygwin and OpenSSH"
title %TITLE%
cls

:: Tested successfully using version 2.874 (DLL 2.5.1) of the Cygwin Setup File on:
::
:: 	Windows 10		[64-Bit]
:: 	Windows 8.1 	[64-Bit]
:: 	Windows 7		[64-Bit]
:: 	Windows 2003	[32-Bit]

REM #################### README #################### > BEGIN
:: Filename:	deploy-cygwin-openssh.bat
:: Version:		3.2
:: Flowchart:	https://db.tt/Piue2nze
:: Latest:		https://pastebin.com/nZjyYRLa
:: Contact:		https://pastebin.com/message_compose?to=J2897
::
:: This script will download and install Cygwin and the OpenSSH package, and then
:: will run SSH-HOST-CONFIG, open the SSH port in Windows Firewall and start the
:: OpenSSH service ready for you to log in via PuTTY using your Windows account.
::
:: If you don't have PowerShell installed, you'll be prompted to manually
:: download the Cygwin Setup File and to put it in the Local Storage Folder.
::
:: List of Microsoft's NT version numbers: http://ss64.com/nt/ver.html
REM #################### README #################### > END

REM Get Window's NT version numbers.
for /f "tokens=2 delims=[]" %%G in ('ver') do (set NT_VER=%%G)
for /f "tokens=2,3,4 delims=. " %%G in ('echo %NT_VER%') do (set V1=%%G& set V2=%%H& set V3=%%I)

REM Figure out which operating system we're using.
if %V1% EQU 10 (set "OS=Windows 10 or Windows Server 2016") else (
	if %V1%.%V2% EQU 6.3 (set "OS=Windows 8.1 or Windows Server 2012 R2") else (
		if %V1%.%V2% EQU 6.2 (set "OS=Windows 8 or Windows Server 2012") else (
			if %V1%.%V2% EQU 6.1 (set "OS=Windows 7 or Windows Server 2008 R2") else (
				if %V1%.%V2% EQU 6.0 (set "OS=Windows Vista or Windows Server 2008") else (
					if %V1% EQU 5 (set "OS=Windows XP or Windows Server 2003") else (
						echo Unsupported operating system.
						echo.
						goto :End
					)
				)
			)
		)
	)
)

if not "%OS%"=="Windows XP or Windows Server 2003" (
	REM Do OPENFILES to check for administrative privileges.
	openfiles >nul
	if errorlevel 1 (
		color cf
		echo Right-click on this file and select "Run as administrator".
		endlocal
		popd
		pause
		color
		exit /b 1
	)
)

color 1b
REM #################### MODIFY #################### > BEGIN
set "AUTO_UPDATE=0" || REM Setting this to 1 will add the upgrade script to the Windows Task Scheduler.
set "PAUSES=0" || REM This toggles all but the last pause.
set "SSH_USER=cyg_server" || REM You'll never use this account. It's used by the Cygwin program only.
set "SSH_PW=q1w2E3R4" || REM You will never need to enter this password. But change it anyway for security reasons.
set "SSH_PORT=22"
set "MIRROR=http://mirrors.kernel.org/sourceware/cygwin/"
set "PACKAGES=openssh,wget,nano,rsync"
REM #################### MODIFY #################### > END

set "TAB=	"
set "SITE=http://cygwin.com"

set "CYGFILE32=setup-x86.exe"
set "CYGFILE64=setup-x86_64.exe"
set "CYGDIR32=%SYSTEMDRIVE%\cygwin"
set "CYGDIR64=%SYSTEMDRIVE%\cygwin64"

set "CU=cyg-upgrade.bat"
set "CU_URL=http://pastebin.com/raw/c2q3SH9T"
set "UCS=update-cygwin-setup.py"
set "UCS_URL=http://pastebin.com/raw/xPN2cYat"

set "INSTALL_LOG=Cygwin Installation.log"
set "SSH_HOST_CONFIG_LOG=Cygwin OpenSSH Host Configuration.log"

if "%SSH_PW%"=="password" (
	echo Please open the "%~nx0" file in a text editor.
	echo.
	echo You must at least change the password between the "modify" lines...
	echo.
	findstr /N "MODIFY" "%~nx0" | find /V "findstr"
	echo.
	goto :End
)

REM #################### HEADER #################### > BEGIN
if "%OS%"=="Windows 10 or Windows Server 2016" (
	set "SPACEX=                    "
) else (
	set "SPACEX="
)
set "SPACELICENSE=    %SPACEX%"
set "SPACETITLE=                           %SPACEX%"
set "SPACENOTE1=                        %SPACEX%"
set "SPACENOTE2=             %SPACEX%"
set "SPACENOTE3=                      %SPACEX%"
echo ^<^<^<%SPACELICENSE%Released under the GNU General Public License version 3+ by J2897.%SPACELICENSE%^>^>^>
echo %SPACETITLE%%TITLE%
echo.
echo %SPACENOTE1%Copyright (C) 2015-2016 J2897.
echo %SPACENOTE2%You are free to change and redistribute this software.
echo %SPACENOTE3%^<http://gnu.org/licenses/gpl.html^>
echo.
REM #################### HEADER #################### > END

REM Detect OS architecture.
set "ARCHITECTURE=64-Bit"
if "%PROCESSOR_ARCHITECTURE%"=="x86" (
	if not defined PROCESSOR_ARCHITEW6432 (set "ARCHITECTURE=32-Bit")
)

REM Select the appropriate Setup File and the Main Cygwin Folder.
if "%ARCHITECTURE%"=="32-Bit" (
	set "SF=%CYGFILE32%"
	set "MCF=%CYGDIR32%"
) else (
	set "SF=%CYGFILE64%"
	set "MCF=%CYGDIR64%"
)

echo Setup File:%TAB%%TAB%%SF%
echo Main Cygwin Folder:%TAB%%MCF%

REM Create the Local Storage Folder.
set "LSF=%SYSTEMDRIVE%\cygstore"
if not exist "%LSF%" (md "%LSF%")
echo Local Storage Folder:%TAB%%LSF%

set "LSSF=%LSF%\scripts"
if %AUTO_UPDATE% EQU 1 (
	REM Create the Local Storage Scripts Folder.
	if not exist "%LSSF%" (md "%LSSF%")
	echo Local Scripts Folder:%TAB%%LSSF%
)

echo.
echo Operating System:%TAB%%OS%
echo NT Version:%TAB%%TAB%%V1%.%V2%

REM Is PowerShell installed?
for /f "tokens=3" %%A in (
	'reg query "HKLM\SOFTWARE\Microsoft\PowerShell\1" /v Install ^| find "Install"'
) do set "POWERSHELLINSTALLED=%%A"
if not "%POWERSHELLINSTALLED%"=="0x1" (
	echo.
	echo PowerShell's not installed. So cannot download the most recent Setup File.
	echo.
	REM Is the Cygwin Setup File in the Local Storage Folder?
	if exist "%LSF%\%SF%" (
		echo Installing the local version instead.
		goto :Install
	) else (
		echo Put the %ARCHITECTURE% Cygwin Setup File in the Local Storage Folder and try again:
		echo %LSF%
		%WINDIR%\explorer.exe "%LSF%"
		echo.
		goto :End
	)
)

REM Does the install log exist?
if exist "%USERPROFILE%\Logs\%INSTALL_LOG%" (
	echo.
	echo Cygwin seems to have already been installed:
	echo %USERPROFILE%\Logs\%INSTALL_LOG%
	echo.
	choice /c YN /m "Would you like to skip this part"
	if not errorlevel 2 (
		echo.
		echo Skipping Cygwin installation . . .
		goto :Configure
	)
)

REM Download the Setup File.
echo.
echo Downloading the Cygwin Setup File to the Local Storage Folder . . .
powershell -command "& { (New-Object Net.WebClient).DownloadFile('%SITE%/%SF%', '%LSF%\%SF%') }"
if not exist "%LSF%\%SF%" (
	echo Failed to download:%TAB%%LSF%\%SF%
	echo.
	goto :End
)

:Install
REM Install Cygwin with the OpenSSH package.
title Deployment of %ARCHITECTURE% Cygwin and OpenSSH in progress...
echo.
echo Installing . . .
if not exist "%USERPROFILE%\Logs" (md "%USERPROFILE%\Logs")
:: https://cygwin.com/faq/faq.html#faq.setup.cli
"%LSF%\%SF%" -q -s "%MIRROR%" -R "%MCF%" -P "%PACKAGES%" -l "%LSF%" >"%USERPROFILE%\Logs\%INSTALL_LOG%"
%WINDIR%\explorer.exe "%USERPROFILE%\Logs"

REM Download Update Scripts.
if %AUTO_UPDATE% EQU 1 (
	echo.
	echo Downloading the Upgrade Scripts to the Local Scripts Folder . . .
	powershell -command "& { (New-Object Net.WebClient).DownloadFile('%CU_URL%', '%LSSF%\%CU%') }"
	powershell -command "& { (New-Object Net.WebClient).DownloadFile('%UCS_URL%', '%LSSF%\%UCS%') }"
) else (goto :Profile)

REM Add task to Windows Task Scheduler.
echo 
set "IMPORT_TASK_FAILED=0"
if "%OS%"=="Windows XP or Windows Server 2003" (
	schtasks /Create /SC MONTHLY /M JAN,FEB,MAR,APR,MAY,JUN,JUL,AUG,SEP,OCT,NOV,DEC /TN "Update Cygwin" /ST 05:00 /TR "%LSSF%\%CU%" /RU %USERNAME% /RP * /F
	if %ERRORLEVEL% NEQ 0 (set "IMPORT_TASK_FAILED=1")
) else (
	schtasks /Create /SC MONTHLY /M JAN,FEB,MAR,APR,MAY,JUN,JUL,AUG,SEP,OCT,NOV,DEC /TN "\Updates\Update Cygwin" /ST 05:00 /TR "%LSSF%\%CU%" /RU %USERNAME% /RP * /RL HIGHEST /F
	if %ERRORLEVEL% NEQ 0 (set "IMPORT_TASK_FAILED=1")
)
if %IMPORT_TASK_FAILED% EQU 1 (
	echo.
	echo If you did not spell your password incorrectly, it may contain incompatible
	echo special characters. So Cygwin will not be upgraded automatically. If this is
	echo important to you, simply add the %CU% file to the Windows Task
	echo Scheduler manually.
	explorer /select,"%LSSF%\%CU%"
)
:Profile
echo.

REM Use the Windows profile folders as the Cygwin home folders.
echo Setting the Windows profile folders as the Cygwin home folders . . .
echo.
::"%MCF%\bin\bash" --login -c "mkpasswd -l -p \"$(cygpath -H)\" > /etc/passwd" || REM This is the old method.
"%MCF%\bin\bash" --login -c "echo \"db_home: windows\" >> /etc/nsswitch.conf" || REM This is the new method recommended by Cygwin.
echo.
move "%MCF%\home\%USERNAME%\*" "%USERPROFILE%"
echo.
if %PAUSES% EQU 1 (pause)
:Configure

REM Does the configuration log exist?
if exist "%USERPROFILE%\Logs\%SSH_HOST_CONFIG_LOG%" (
	echo OpenSSH seems to have already been configured:
	echo %USERPROFILE%\Logs\%SSH_HOST_CONFIG_LOG%
	echo.
	choice /c YN /m "Would you like to skip this part"
	if not errorlevel 2 (
		echo.
		echo Skipping OpenSSH host configuration . . .
		echo.
		goto :Firewall
	) else (
		echo.
	)
)

REM Configure OpenSSH.
echo Configuring OpenSSH . . .
echo.
if not exist "%USERPROFILE%\Logs" (md "%USERPROFILE%\Logs")
"%MCF%\bin\bash" --login -c "/bin/ssh-host-config -y -p %SSH_PORT% -u %SSH_USER% -w %SSH_PW%" | more /E /P >"%USERPROFILE%\Logs\%SSH_HOST_CONFIG_LOG%" 2>&1

REM Prepare PKA and set the correct permissions.
echo Preparing Public Key Authentication...
"%MCF%\bin\bash" --login -c "echo \"StrictModes no\" >> /etc/sshd_config"
if not exist "%USERPROFILE%\.ssh" (
	"%MCF%\bin\bash" --login -c "mkdir ~/.ssh;setfacl -b ~/.ssh;chmod 700 ~/.ssh;touch ~/.ssh/authorized_keys;chmod 600 ~/.ssh/authorized_keys"
) else (
	"%MCF%\bin\bash" --login -c "setfacl -b ~/.ssh;chmod 700 ~/.ssh"
	if not exist "%USERPROFILE%\.ssh\authorized_keys" (
		"%MCF%\bin\bash" --login -c "touch ~/.ssh/authorized_keys;chmod 600 ~/.ssh/authorized_keys"
	) else (
		"%MCF%\bin\bash" --login -c "chmod 600 ~/.ssh/authorized_keys"
	)
)
echo.

REM Remove user from the Windows Logon screen.
echo Removing %SSH_USER% from the Windows Logon screen . . .
echo.
reg add "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" /v %SSH_USER% /t REG_DWORD /d 0 /f
echo.
if %PAUSES% EQU 1 (pause & echo.)

:Firewall
REM Punch a hole through Windows Firewall.
echo Openning TCP port %SSH_PORT% in Windows Firewall . . .
echo.
if "%OS%"=="Windows XP or Windows Server 2003" (
	netsh firewall add portopening protocol=TCP port=%SSH_PORT% name=OpenSSH
) else (
	netsh advfirewall firewall add rule name=OpenSSH dir=in action=allow protocol=tcp localport=%SSH_PORT%
)
if %PAUSES% EQU 1 (pause & echo.)

REM Start OpenSSH.
echo Starting OpenSSH . . .
echo.
net start sshd

REM Display connection information.
echo Connect to:
echo.

:: Connect by local IPv4 address...
if "%OS%"=="Windows XP or Windows Server 2003" (
	for /F "tokens=2 delims=:" %%I in ('"ipconfig | findstr Address"') do set "LOCAL_IP=%%I"
) else (
	for /F "tokens=2 delims=:" %%I in ('"ipconfig | findstr IPv4"') do set "LOCAL_IP=%%I"
)
set "LOCAL_IP=%LOCAL_IP: =%"
echo %TAB%%USERNAME%^@%LOCAL_IP%

:: Connect by fully qualified domain name...
for /f "tokens=2,* delims= " %%A in ('ipconfig ^/all ^| findstr "Primary Dns"') do set "TEMPSUFFIX=%%B"
for /f "tokens=1,2 delims=:" %%A in ('echo %TEMPSUFFIX%') do set "DNSSUFFIX=%%B"
set "FQDN=%COMPUTERNAME%.%DNSSUFFIX:~1%"
if not "%DNSSUFFIX%"==" " (
	echo %TAB%%USERNAME%^@%FQDN%
)

echo.
echo Use the same password that you use to log in to Windows.
echo.
echo Alternatively, Public Key Authentication is set up too. So you can just add
echo your key to the ~/.ssh/authorized_keys file. Typing 'rsshd' will restart the
echo service, although that should not be necessary.
echo.
echo Remember to adjust the settings in the /etc/sshd_config file to harden your
echo server's security.
echo.
"%MCF%\bin\bash" --login -c "echo \"alias rsshd='net stop sshd ^&^& net start sshd'\" >> ~/.bashrc"

:End
endlocal
popd
title Finished.
rem pause
color
