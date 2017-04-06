@setlocal EnableDelayedExpansion EnableExtensions

title Installing Custom Stuff. Please wait...

echo Downloading Ninite
set NINITE_URL=https://ninite.com/.net4.6.2-7zip-chrome-classicstart-java8-libreoffice-notepadplusplus-pdfcreator-sumatrapdf-vscode-winmerge/ninite.exe

for %%i in (%NINITE_URL%) do set NINITE_EXE=%%~nxi
set NINITE_DIR=%USERPROFILE%\Desktop
set NINITE_PATH=%NINITE_DIR%\%NINITE_EXE%

echo ==^> Creating "%NINITE_DIR%"
mkdir "%NINITE_DIR%"
pushd "%NINITE_DIR%"

if exist "%SystemRoot%\_download.cmd" (
  call "%SystemRoot%\_download.cmd" "%NINITE_URL%" "%NINITE_PATH%"
) else (
  echo ==^> Downloading "%NINITE_URL%" to "%NINITE_PATH%"
  powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%NINITE_URL%', '%NINITE_PATH%')" <NUL
)

echo Installing 7-zip
set SEVENZIP_URL=http://www.7-zip.org/a/7z1604-x64.msi
set TEMP_PATH="C:\Windows\Temp"
for %%i in (%SEVENZIP_URL%) do set SEVENZIP_EXE=%%~nxi
set SEVENZIP_PATH=%TEMP_PATH%\%SEVENZIP_EXE%
if exist "%SystemRoot%\_download.cmd" (
  call "%SystemRoot%\_download.cmd" "%SEVENZIP_URL%" "%SEVENZIP_PATH%"
)
%SEVENZIP_PATH% /qn /passive


set WINISO="C:\Windows\Temp\windows.iso"
if exist "%WINISO%" (
  echo Installing VM Tools
  "%ProgramFiles%\7-Zip\7z.exe" x C:\Windows\Temp\windows.iso -oC:\Windows\Temp\vmfolder

  if exist "C:\Windows\Temp\vmfolder\setup64.exe" (
    echo Installing VMWare tools
    START /W C:\Windows\Temp\vmfolder\setup64.exe /s /v/qr REBOOT=R
  )
  if exist "C:\Windows\Temp\vmfolder\VBoxWindowsAdditions.exe" (
    echo Installing Virtualbox tools
    C:\Windows\Temp\vmfolder\cert\VBoxCertUtil.exe add-trusted-publisher C:\Windows\Temp\vmfolder\cert\vbox-sha1.cer
    START /W C:\Windows\Temp\vmfolder\VBoxWindowsAdditions.exe /S
  )

  echo Cleaning up
  rmdir /q /s C:\Windows\Temp\vmfolder
  del C:\Windows\Temp\windows.iso

)

echo Extra Folder Options
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v ShowSuperHidden /t REG_DWORD /d 1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v LaunchTo /t REG_DWORD /d 1

echo Hide Search bar
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /V SearchboxTaskbarMode /T REG_DWORD /D 0 /F

echo Set small icons for taskbar
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V TaskbarSmallIcons /T REG_DWORD /D 1 /F

echo Show taskbar on multiple displays
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V MMTaskbarEnabled /T REG_dWORD /D 1 /F
REG ADD "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V MMTaskbarMode /T REG_dWORD /D 2 /F
echo Combine taskbar items only when full
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V TaskbarGlomLevel /T REG_DWORD /D 1 /F
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V MMTaskbarGlomLevel /T REG_dWORD /D 1 /F

:exit0

ver>nul

goto :exit

:exit1

verify other 2>nul

:exit
