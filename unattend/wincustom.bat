@setlocal EnableDelayedExpansion EnableExtensions

title Installing Custom Stuff. Please wait...

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
if not exist "%NINITE_PATH%" goto exit1

:exit0

ver>nul

goto :exit

:exit1

verify other 2>nul

:exit
