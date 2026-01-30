#!/usr/bin/env python
"""Auto-install Lua 5.4+ for frictionless MCP server usage."""
import os
import sys
import subprocess
import urllib.request
import zipfile
import shutil
import ssl
from pathlib import Path

def get_lua_dir():
    """Get directory where bundled Lua should be installed."""
    return Path(__file__).parent / "bin" / "lua"

def is_lua55_available():
    """Check if Lua 5.5+ is available in PATH or bundled."""
    bundled_luac = get_lua_dir() / "luac55.exe"
    if bundled_luac.exists():
        return True
    
    candidates = ["luac5.5", "luac55", "luac5.4", "luac54"]
    for cmd in candidates:
        try:
            subprocess.run([cmd, "-v"], capture_output=True, timeout=1.0, check=False)
            return True
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    
    return False

def download_file(url, target_path, timeout=120):
    """Download file using urllib with SSL context and proper headers."""
    try:
        context = ssl._create_unverified_context()
        
        req = urllib.request.Request(
            url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'application/zip, application/octet-stream, */*',
                'Accept-Language': 'en-US,en;q=0.9',
                'Referer': 'https://sourceforge.net/'
            }
        )
        
        with urllib.request.urlopen(req, context=context, timeout=timeout) as response:
            with open(target_path, 'wb') as out_file:
                shutil.copyfileobj(response, out_file)
        
        return target_path.exists() and target_path.stat().st_size > 1000
    except Exception as e:
        print(f"[Lua Setup] Download failed: {e}")
        return False

def download_and_install_lua():
    """Download and install Lua 5.5.0 to bundled location."""
    lua_dir = get_lua_dir()
    lua_dir.mkdir(parents=True, exist_ok=True)
    
    urls = [
        "https://sourceforge.net/projects/luabinaries/files/5.5.0/Tools%20Executables/lua-5.5.0_Win64_bin.zip",
        "https://sourceforge.net/projects/luabinaries/files/5.5.1/Tools%20Executables/lua-5.5.1_Win64_bin.zip",
        "https://sourceforge.net/projects/luabinaries/files/5.5.4/Tools%20Executables/lua-5.5.4_Win64_bin.zip",
        "https://github.com/rjpcomputing/luaforwindows/releases/download/v5.5.0/lua-5.5.0_Win64_bin.zip",
    ]
    
    print("[Lua Setup] Lua 5.5.0 not found, auto-installing...")
    
    for url in urls:
        try:
            zip_path = lua_dir / "lua_temp.zip"
            
            if zip_path.exists():
                zip_path.unlink()
            
            print(f"[Lua Setup] Trying: {url.split('/')[-2] if '/' in url else url}")
            
            if download_file(url, zip_path):
                print(f"[Lua Setup] Downloaded successfully")
                
                try:
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        zip_ref.extractall(lua_dir)
                    
                    zip_path.unlink()
                    
                    luac_exe = lua_dir / "luac.exe"
                    luac55_exe = lua_dir / "luac55.exe"
                    luac5_5_exe = lua_dir / "luac5.5.exe"
                    luac54_exe = lua_dir / "luac54.exe"
                    luac5_4_exe = lua_dir / "luac5.4.exe"
                    
                    if luac_exe.exists():
                        # Create 5.5 versions first
                        shutil.copy(luac_exe, luac55_exe)
                        shutil.copy(luac_exe, luac5_5_exe)
                        # Also create 5.4 fallbacks
                        shutil.copy(luac_exe, luac54_exe)
                        shutil.copy(luac_exe, luac5_4_exe)
                        print(f"[Lua Setup] ✓ Installed Lua 5.5.0 to: {lua_dir}")
                        print(f"[Lua Setup] ✓ Created: luac55.exe, luac5.5.exe, luac54.exe, luac5.4.exe")
                        return lua_dir
                    else:
                        for file in lua_dir.iterdir():
                            if file.name.lower().startswith('luac') and file.suffix == '.exe':
                                # Create both 5.5 and 5.4 versions
                                shutil.copy(file, luac55_exe)
                                shutil.copy(file, luac5_5_exe)
                                shutil.copy(file, luac54_exe)
                                shutil.copy(file, luac5_4_exe)
                                print(f"[Lua Setup] ✓ Installed Lua 5.5.0 to: {lua_dir}")
                                return lua_dir
                    
                except zipfile.BadZipFile:
                    print(f"[Lua Setup] Invalid zip, trying next source...")
                    if zip_path.exists():
                        zip_path.unlink()
                    continue
                except Exception as e:
                    print(f"[Lua Setup] Extract failed: {e}")
                    if zip_path.exists():
                        zip_path.unlink()
                    continue
        except Exception as e:
            print(f"[Lua Setup] Attempt failed: {e}")
            continue
    
    print("[Lua Setup] ⚠ All download methods failed")
    print("[Lua Setup] Manual installation required:")
    print(f"[Lua Setup] 1. Download Lua 5.5.0 from: https://luabinaries.sourceforge.net/")
    print(f"[Lua Setup] 2. Extract luac.exe to: {lua_dir}")
    print(f"[Lua Setup] 3. Rename to: luac55.exe")
    
    raise RuntimeError(
        f"Failed to auto-install Lua 5.5.0.\n"
        f"Place luac55.exe in: {lua_dir}\n"
        f"Download from: https://luabinaries.sourceforge.net/"
    )

def ensure_lua_available():
    """Ensure Lua 5.5.0 is available, install if needed."""
    if is_lua55_available():
        print("[Lua Setup] ✓ Lua 5.5.0 detected")
        return True
    
    try:
        download_and_install_lua()
        return True
    except Exception as e:
        print(f"[Lua Setup] ✗ Auto-install failed: {e}")
        return False

if __name__ == "__main__":
    success = ensure_lua_available()
    sys.exit(0 if success else 1)
