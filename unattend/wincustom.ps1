$temppath = "C:\Windows\Temp"

# Check if Windows 7
if ([Environment]::OSVersion.Version -ge (new-object 'Version' 6,1)){
  # Install .net Framework 4.5.2 on Windows 7
  $url = "https://download.microsoft.com/download/9/A/7/9A78F13F-FD62-4F6D-AB6B-1803508A9F56/51209.34209.03/web/NDP452-KB2901954-Web.exe"
  $netfile = "$temppath\NDP452-KB2901954-Web.exe"
  (New-Object System.Net.WebClient).DownloadFile($url, $netfile)
  Start-Process -Wait "$netfile" "/quiet"
  Remove-Item -Recurse -Force $netfile

  # Check if Powershell is less than 4
  if ($PSVersionTable.PSVersion.Major -lt 4){
    # Install Powershell 5 on Windows 7
    $url = "https://download.microsoft.com/download/6/F/5/6F5FF66C-6775-42B0-86C4-47D41F2DA187/Win7AndW2K8R2-KB3191566-x64.zip"
    $psfile = "$temppath\Win7AndW2K8R2-KB3191566-x64.zip"
    (New-Object System.Net.WebClient).DownloadFile($url, $psfile)
    $psfolder = "$temppath\psfolder"
    & "C:\Program Files\7-Zip\7z.exe" "x" "$psfile" "-o$psfolder" | Out-Null
    Start-Process -Wait "$psfolder\Win7AndW2K8R2-KB3191566-x64.msu" "/quiet" "/norestart"
    Remove-Item -Recurse -Force $psfolder
    Remove-Item -Recurse -Force $psfile
  }
}
