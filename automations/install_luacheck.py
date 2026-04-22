#!/usr/bin/env python
"""Auto-install luacheck for frictionless MCP server usage."""
import os
import sys
import subprocess
import urllib.request
import zipfile
import shutil
import ssl
from pathlib import Path

def get_luacheck_dir():
    """Get directory where bundled luacheck should be installed."""
    return Path(__file__).parent / "bin" / "luacheck"

def is_luacheck_available():
    """Check if luacheck is available in PATH or bundled."""
    bundled_luacheck = get_luacheck_dir() / "luacheck.exe"
    if bundled_luacheck.exists():
        return True
    
    try:
        subprocess.run(["luacheck", "--version"], capture_output=True, timeout=1.0, check=False)
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    
    return False

def download_file(url, target_path, timeout=120):
    """Download file using urllib with SSL context."""
    try:
        context = ssl._create_unverified_context()
        
        req = urllib.request.Request(
            url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
        )
        
        with urllib.request.urlopen(req, context=context, timeout=timeout) as response:
            with open(target_path, 'wb') as out_file:
                shutil.copyfileobj(response, out_file)
        
        return target_path.exists() and target_path.stat().st_size > 1000
    except Exception as e:
        print(f"[Luacheck Setup] Download failed: {e}")
        return False

def download_and_install_luacheck():
    """Download and install luacheck via Luarocks or pre-built binary."""
    luacheck_dir = get_luacheck_dir()
    luacheck_dir.mkdir(parents=True, exist_ok=True)
    
    print("[Luacheck Setup] luacheck not found, auto-installing...")
    
    # Try direct download of luacheck binary (Windows)
    urls = [
        "https://github.com/mpeterv/luacheck/releases/download/0.26.1/luacheck-0.26.1-0.x86_64-w64-mingw32.zip",
        "https://github.com/mpeterv/luacheck/releases/download/0.26.0/luacheck-0.26.0-0.x86_64-w64-mingw32.zip",
    ]
    
    for url in urls:
        try:
            zip_path = luacheck_dir / "luacheck_temp.zip"
            
            if zip_path.exists():
                zip_path.unlink()
            
            print(f"[Luacheck Setup] Trying: {url.split('/')[-1]}")
            
            if download_file(url, zip_path):
                print(f"[Luacheck Setup] Downloaded successfully")
                
                try:
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        zip_ref.extractall(luacheck_dir)
                    
                    zip_path.unlink()
                    
                    # Find luacheck.exe in extracted files
                    for root, dirs, files in os.walk(luacheck_dir):
                        for file in files:
                            if file.lower() == "luacheck.exe":
                                src = Path(root) / file
                                dst = luacheck_dir / "luacheck.exe"
                                if src != dst:
                                    shutil.copy2(src, dst)
                                print(f"[Luacheck Setup] ✓ Installed luacheck to: {luacheck_dir}")
                                return luacheck_dir
                    
                except zipfile.BadZipFile:
                    print(f"[Luacheck Setup] Invalid zip, trying next source...")
                    if zip_path.exists():
                        zip_path.unlink()
                    continue
                except Exception as e:
                    print(f"[Luacheck Setup] Extract failed: {e}")
                    if zip_path.exists():
                        zip_path.unlink()
                    continue
        except Exception as e:
            print(f"[Luacheck Setup] Attempt failed: {e}")
            continue
    
    print("[Luacheck Setup] ⚠ Binary download failed, attempting alternative installation...")
    
    # Try installing via pip if available
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "luacheck"],
            capture_output=True,
            timeout=120,
            check=False
        )
        if result.returncode == 0:
            print("[Luacheck Setup] ✓ Installed luacheck via pip")
            return True
    except Exception as e:
        print(f"[Luacheck Setup] pip install failed: {e}")
    
    # Try Luarocks if available
    try:
        result = subprocess.run(
            ["luarocks", "install", "luacheck"],
            capture_output=True,
            timeout=120,
            check=False
        )
        if result.returncode == 0:
            print("[Luacheck Setup] ✓ Installed luacheck via Luarocks")
            return True
    except Exception as e:
        print(f"[Luacheck Setup] Luarocks install failed: {e}")
    
    print("[Luacheck Setup] ⚠ All auto-install methods failed")
    print("[Luacheck Setup] Manual installation required:")
    print("[Luacheck Setup] Option 1: npm install -g luacheck (requires Node.js)")
    print("[Luacheck Setup] Option 2: pip install luacheck (requires Python)")
    print("[Luacheck Setup] Option 3: Download binary from: https://github.com/mpeterv/luacheck/releases")
    print(f"[Luacheck Setup] Option 4: Place luacheck.exe in: {luacheck_dir}")
    
    raise RuntimeError(
        f"Failed to auto-install luacheck.\n"
        f"Try: pip install luacheck\n"
        f"Or: npm install -g luacheck\n"
        f"Or download from: https://github.com/mpeterv/luacheck/releases"
    )

def ensure_luacheck_available():
    """Ensure luacheck is available, install if needed."""
    if is_luacheck_available():
        print("[Luacheck Setup] ✓ luacheck detected")
        return True
    
    try:
        download_and_install_luacheck()
        return True
    except Exception as e:
        print(f"[Luacheck Setup] ✗ Auto-install failed: {e}")
        return False

if __name__ == "__main__":
    success = ensure_luacheck_available()
    sys.exit(0 if success else 1)
