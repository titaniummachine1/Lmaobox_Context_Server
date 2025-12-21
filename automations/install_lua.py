#!/usr/bin/env python
"""Auto-install Lua 5.4+ for frictionless MCP server usage."""
import os
import sys
import subprocess
import urllib.request
import zipfile
import shutil
from pathlib import Path

LUA_VERSION = "5.4.2"
LUA_DOWNLOAD_URL = f"https://sourceforge.net/projects/luabinaries/files/{LUA_VERSION}/Tools%20Executables/lua-{LUA_VERSION}_Win64_bin.zip/download"

def get_lua_dir():
    """Get directory where bundled Lua should be installed."""
    return Path(__file__).parent / "bin" / "lua"

def is_lua54_available():
    """Check if Lua 5.4+ is available in PATH or bundled."""
    bundled_luac = get_lua_dir() / "luac54.exe"
    if bundled_luac.exists():
        return True
    
    candidates = ["luac5.4", "luac54", "luac5.5", "luac55"]
    for cmd in candidates:
        try:
            subprocess.run([cmd, "-v"], capture_output=True, timeout=1.0, check=False)
            return True
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    
    return False

def download_and_install_lua():
    """Download and install Lua 5.4+ to bundled location."""
    lua_dir = get_lua_dir()
    lua_dir.mkdir(parents=True, exist_ok=True)
    
    zip_path = lua_dir / "lua.zip"
    
    urls = [
        (f"https://github.com/lua/lua/releases/download/v5.4.7/lua-5.4.7.tar.gz", "lua-5.4.7.tar.gz"),
        (LUA_DOWNLOAD_URL, "lua.zip"),
    ]
    
    print(f"[Lua Setup] Downloading Lua {LUA_VERSION}...")
    
    for url, filename in urls:
        try:
            target_path = lua_dir / filename
            
            result = subprocess.run(
                ["curl", "-L", "-o", str(target_path), url],
                capture_output=True,
                timeout=60,
                check=False
            )
            
            if result.returncode == 0 and target_path.exists() and target_path.stat().st_size > 1000:
                print(f"[Lua Setup] Downloaded from {url}")
                
                if filename.endswith('.zip'):
                    try:
                        with zipfile.ZipFile(target_path, 'r') as zip_ref:
                            zip_ref.extractall(lua_dir)
                        target_path.unlink()
                        
                        luac_exe = lua_dir / "luac.exe"
                        if luac_exe.exists():
                            luac54_exe = lua_dir / "luac54.exe"
                            shutil.copy(luac_exe, luac54_exe)
                            print(f"[Lua Setup] Installed: {luac54_exe}")
                            return lua_dir
                    except zipfile.BadZipFile:
                        print(f"[Lua Setup] Invalid zip file, trying next source...")
                        target_path.unlink()
                        continue
        except Exception as e:
            print(f"[Lua Setup] Download attempt failed: {e}")
            continue
    
    print("[Lua Setup] All download methods failed")
    print("[Lua Setup] Creating skip marker - validation will use fallback Lua if available")
    (lua_dir / ".skip_auto_install").touch()
    
    raise RuntimeError(
        f"Failed to auto-install Lua {LUA_VERSION}.\n"
        f"For modern syntax support, manually install Lua 5.4+ from:\n"
        f"https://luabinaries.sourceforge.net/download.html\n"
        f"Or place luac54.exe in: {lua_dir}"
    )

def ensure_lua_available():
    """Ensure Lua 5.4+ is available, install if needed."""
    if is_lua54_available():
        return True
    
    lua_dir = get_lua_dir()
    skip_marker = lua_dir / ".skip_auto_install"
    
    if skip_marker.exists():
        return False
    
    print("[Lua Setup] Lua 5.4+ not found, attempting auto-install...")
    try:
        download_and_install_lua()
        return True
    except Exception as e:
        print(f"[Lua Setup] Auto-install failed - will use fallback if available")
        return False

if __name__ == "__main__":
    ensure_lua_available()
