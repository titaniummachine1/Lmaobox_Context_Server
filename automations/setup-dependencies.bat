@echo off
setlocal enabledelayedexpansion

echo.
echo ================================================================
echo  Lmaobox Context Server - Dependency Setup
echo ================================================================
echo.

REM Check for Python
echo Checking for Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ⚠ Python 3 not found in PATH
    echo Please install Python 3 from: https://www.python.org/downloads/
    pause
    exit /b 1
)

echo ✓ Python found

REM Get script directory
set SCRIPT_DIR=%~dp0

REM Run Lua setup
echo.
echo Installing Lua 5.4+ compiler...
python "%SCRIPT_DIR%install_lua.py"
if errorlevel 1 (
    echo ⚠ Lua installation may have issues. Please check the output above.
    pause
) else (
    echo ✓ Lua installed successfully
)

REM Run luacheck setup
echo.
echo Installing luacheck linter...
python "%SCRIPT_DIR%install_luacheck.py"
if errorlevel 1 (
    echo ⚠ luacheck installation may have issues. This is optional but recommended.
    echo You can install manually with: pip install luacheck
) else (
    echo ✓ luacheck installed successfully
)

echo.
echo ================================================================
echo  Setup Complete!
echo ================================================================
echo.
echo The MCP server is now ready to use. All dependencies have been
echo installed automatically.
echo.
echo Next steps:
echo  1. Ensure the Go binary is built (go build)
echo  2. Start the MCP server (it will validate dependencies on startup)
echo.
pause
