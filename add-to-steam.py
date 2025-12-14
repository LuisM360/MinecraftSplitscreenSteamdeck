#!/usr/bin/env python3
# --- Minecraft Splitscreen Steam Shortcut Adder ---
# This script adds a custom Minecraft Splitscreen launcher to Steam's shortcuts.vdf,
# and downloads SteamGridDB artwork for a polished look in your Steam library.
# It is designed to work for any Linux user (not just Steam Deck).
#
# Based on the original script by ArnoldSmith86:
# https://github.com/ArnoldSmith86/minecraft-splitscreen
# Modified and improved for portability and clarity.

import os
import re
import struct
import zlib
import urllib.request
import json
import time

# --- Config: Set up paths and app info dynamically for the current user ---
HOME = os.path.expanduser("~")  # Get the current user's home directory
APPNAME  = "Minecraft Splitscreen"  # Name as it will appear in Steam

# Detect which launcher is being used (PollyMC or PrismLauncher)
def detect_launcher():
    """Detect available launcher (PollyMC or PrismLauncher) for splitscreen gameplay."""
    # #region agent log
    log_data = {
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "A",
        "location": "add-to-steam.py:detect_launcher",
        "message": "Starting launcher detection",
        "data": {"home": HOME},
        "timestamp": int(time.time() * 1000)
    }
    try:
        with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
            f.write(json.dumps(log_data) + "\n")
    except: pass
    # #endregion
    
    pollymc_path = f'{HOME}/.local/share/PollyMC/PollyMC-Linux-x86_64.AppImage'
    pollymc_script = f'{HOME}/.local/share/PollyMC/minecraftSplitscreen.sh'
    prism_path = f'{HOME}/.local/share/PrismLauncher/PrismLauncher.AppImage'
    prism_script = f'{HOME}/.local/share/PrismLauncher/minecraftSplitscreen.sh'
    
    # #region agent log
    log_data = {
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "A",
        "location": "add-to-steam.py:detect_launcher",
        "message": "Checking PollyMC paths",
        "data": {
            "pollymc_path_exists": os.path.exists(pollymc_path),
            "pollymc_path_executable": os.access(pollymc_path, os.X_OK) if os.path.exists(pollymc_path) else False,
            "pollymc_script_exists": os.path.exists(pollymc_script)
        },
        "timestamp": int(time.time() * 1000)
    }
    try:
        with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
            f.write(json.dumps(log_data) + "\n")
    except: pass
    # #endregion
    
    # Check for PollyMC first (legacy support)
    if os.path.exists(pollymc_path) and os.access(pollymc_path, os.X_OK):
        if os.path.exists(pollymc_script):
            # #region agent log
            log_data = {
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "A",
                "location": "add-to-steam.py:detect_launcher",
                "message": "PollyMC detected successfully",
                "data": {"launcher": "PollyMC", "script": pollymc_script, "dir": f"{HOME}/.local/share/PollyMC"},
                "timestamp": int(time.time() * 1000)
            }
            try:
                with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
                    f.write(json.dumps(log_data) + "\n")
            except: pass
            # #endregion
            return pollymc_script, f"{HOME}/.local/share/PollyMC", "PollyMC"
        else:
            # Use the script from current directory if PollyMC directory doesn't have it
            # #region agent log
            log_data = {
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "A",
                "location": "add-to-steam.py:detect_launcher",
                "message": "PollyMC found but script missing, using fallback",
                "data": {"launcher": "PollyMC", "script": f"{HOME}/.local/share/PrismLauncher/minecraftSplitscreen.sh"},
                "timestamp": int(time.time() * 1000)
            }
            try:
                with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
                    f.write(json.dumps(log_data) + "\n")
            except: pass
            # #endregion
            return f"{HOME}/.local/share/PrismLauncher/minecraftSplitscreen.sh", f"{HOME}/.local/share/PollyMC", "PollyMC"
    
    # #region agent log
    log_data = {
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "B",
        "location": "add-to-steam.py:detect_launcher",
        "message": "Checking PrismLauncher paths",
        "data": {
            "prism_path_exists": os.path.exists(prism_path),
            "prism_path_executable": os.access(prism_path, os.X_OK) if os.path.exists(prism_path) else False,
            "prism_script_exists": os.path.exists(prism_script)
        },
        "timestamp": int(time.time() * 1000)
    }
    try:
        with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
            f.write(json.dumps(log_data) + "\n")
    except: pass
    # #endregion
    
    # Fallback: Check for PrismLauncher (since PollyMC was discontinued)
    if os.path.exists(prism_path) and os.access(prism_path, os.X_OK):
        if os.path.exists(prism_script):
            # #region agent log
            log_data = {
                "sessionId": "debug-session",
                "runId": "run1",
                "hypothesisId": "B",
                "location": "add-to-steam.py:detect_launcher",
                "message": "PrismLauncher detected successfully",
                "data": {"launcher": "PrismLauncher", "script": prism_script, "dir": f"{HOME}/.local/share/PrismLauncher"},
                "timestamp": int(time.time() * 1000)
            }
            try:
                with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
                    f.write(json.dumps(log_data) + "\n")
            except: pass
            # #endregion
            return prism_script, f"{HOME}/.local/share/PrismLauncher", "PrismLauncher"
        else:
            # Check if script exists in current directory as fallback
            current_dir_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "minecraftSplitscreen.sh")
            if os.path.exists(current_dir_script):
                # #region agent log
                log_data = {
                    "sessionId": "debug-session",
                    "runId": "run1",
                    "hypothesisId": "B",
                    "location": "add-to-steam.py:detect_launcher",
                    "message": "PrismLauncher found but script missing, using current directory script",
                    "data": {"launcher": "PrismLauncher", "script": current_dir_script, "dir": f"{HOME}/.local/share/PrismLauncher"},
                    "timestamp": int(time.time() * 1000)
                }
                try:
                    with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
                        f.write(json.dumps(log_data) + "\n")
                except: pass
                # #endregion
                return current_dir_script, f"{HOME}/.local/share/PrismLauncher", "PrismLauncher"
    
    # #region agent log
    log_data = {
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "C",
        "location": "add-to-steam.py:detect_launcher",
        "message": "No launcher found - error condition",
        "data": {
            "pollymc_path": pollymc_path,
            "prism_path": prism_path,
            "pollymc_exists": os.path.exists(pollymc_path),
            "prism_exists": os.path.exists(prism_path)
        },
        "timestamp": int(time.time() * 1000)
    }
    try:
        with open("/home/luis/Desktop/Projects/openrepos/myfork/MinecraftSplitscreenSteamdeck/.cursor/debug.log", "a") as f:
            f.write(json.dumps(log_data) + "\n")
    except: pass
    # #endregion
    
    # If neither launcher found, show helpful error
    print("❌ Error: No compatible Minecraft launcher found!")
    print(f"   Expected PollyMC at: {pollymc_path}")
    print(f"   Or PrismLauncher at: {prism_path}")
    print("   Please run the Minecraft Splitscreen installer to set up a launcher")
    exit(1)

EXE, STARTDIR, LAUNCHER_NAME = detect_launcher()
print(f"📱 Detected launcher: {LAUNCHER_NAME}")
print(f"🚀 Launch script: {EXE}")
print(f"📁 Working directory: {STARTDIR}")

# SteamGridDB artwork URLs for custom grid images, hero, logo, and icon
STEAMGRIDDB_IMAGES = {
    "p": "https://cdn2.steamgriddb.com/grid/a73027901f88055aaa0fd1a9e25d36c7.png",  # Portrait grid
    "": "https://cdn2.steamgriddb.com/grid/e353b610e9ce20f963b4cca5da565605.jpg",      # Main grid
    "_hero": "https://cdn2.steamgriddb.com/hero/ecd812da02543c0269cfc2c56ab3c3c0.png", # Hero image
    "_logo": "https://cdn2.steamgriddb.com/logo/90915208c601cc8c86ad01250ee90c12.png", # Logo
    "_icon": "https://cdn2.steamgriddb.com/icon/add7a048049671970976f3e18f21ade3.ico"   # Icon
}

# --- Locate Steam shortcuts file for the current user ---
userdata = os.path.expanduser("~/.steam/steam/userdata")  # Steam userdata directory
user_id = next((d for d in os.listdir(userdata) if d.isdigit()), None)  # Find the first numeric user ID
if not user_id:
    print("❌ No Steam user found.")
    exit(1)
config_dir = os.path.join(userdata, user_id, "config")  # Path to config directory
shortcuts_file = os.path.join(config_dir, "shortcuts.vdf")  # Path to shortcuts.vdf

# --- Ensure shortcuts.vdf exists (create if missing) ---
if not os.path.exists(shortcuts_file):
    with open(shortcuts_file, "wb") as f:
        f.write(b'\x00shortcuts\x00\x08\x08')  # Write empty VDF structure

# --- Read current shortcuts.vdf into memory ---
with open(shortcuts_file, "rb") as f:
    data = f.read()

def get_latest_index(data):
    """
    Find the highest shortcut index in the VDF file.
    Steam shortcuts are stored as binary blobs with indices: \x00<index>\x00
    """
    matches = re.findall(rb'\x00(\d+)\x00', data)
    if matches:
        return int(matches[-1])
    return -1

# --- Determine the next shortcut index ---
index = get_latest_index(data) + 1

# --- Helper: Create a binary shortcut entry for Steam's VDF format ---
def make_entry(index, appid, appname, exe, startdir):
    """
    Build a binary VDF entry for a Steam shortcut.
    Args:
        index (int): Shortcut index
        appid (int): Unique app ID
        appname (str): Name in Steam
        exe (str): Executable path
        startdir (str): Working directory
    Returns:
        bytes: Binary VDF entry
    """
    x00 = b'\x00'; x01 = b'\x01'; x02 = b'\x02'; x08 = b'\x08'
    b = b''
    b += x00 + str(index).encode() + x00  # Shortcut index
    b += x02 + b'appid' + x00 + struct.pack('<I', appid)  # AppID
    b += x01 + b'appname' + x00 + appname.encode() + x00  # App name
    b += x01 + b'exe' + x00 + exe.encode() + x00          # Executable
    b += x01 + b'StartDir' + x00 + startdir.encode() + x00  # Working dir
    b += x01 + b'icon' + x00 + config_dir.encode() + b'/grid/' + str(appid).encode() + b'_icon.ico' + x00  # Icon path
    b += x08  # End of entry
    return b

# --- Generate a unique appid for the shortcut (matches Steam's logic) ---
appid = 0x80000000 | zlib.crc32((APPNAME + EXE).encode("utf-8")) & 0xFFFFFFFF
entry = make_entry(index, appid, APPNAME, EXE, STARTDIR)

# --- Insert the new shortcut entry before the last two \x08 bytes (end of VDF) ---
if data.endswith(b'\x08\x08'):
    new_data = data[:-2] + entry + b'\x08\x08'
    with open(shortcuts_file, "wb") as f:
        f.write(new_data)
    print(f"✅ Minecraft shortcut added with index {index} and appid {appid}")
else:
    print("❌ File structure not recognized. No changes made.")
    exit(1)

# --- Download SteamGridDB artwork for the new shortcut ---
grid_dir = os.path.join(userdata, user_id, "config", "grid")  # Path to grid images
os.makedirs(grid_dir, exist_ok=True)  # Ensure grid directory exists

for suffix, url in STEAMGRIDDB_IMAGES.items():
    # Determine file extension based on URL
    path = os.path.join(grid_dir, f"{appid}{suffix}.png" if not url.endswith(".ico") else f"{appid}{suffix}.ico")
    if os.path.exists(path):
        print(f"✅ Skipping {suffix} image — already exists.")
        continue
    try:
        print(f"Downloading: {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req) as resp, open(path, "wb") as out:
            out.write(resp.read())
        print(f"✅ Saved {suffix} image.")
    except Exception as e:
        print(f"⚠️ Failed to download {suffix} image: {e}")

print("✅ All done. Launch Steam to see Minecraft in your Library.")
