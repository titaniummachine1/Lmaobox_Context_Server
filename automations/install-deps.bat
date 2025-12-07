@echo off
echo Installing dependencies...
cd /d "%~dp0"
call npm install
if %ERRORLEVEL% EQU 0 (
    echo Dependencies installed successfully!
) else (
    echo Failed to install dependencies
    exit /b 1
)
