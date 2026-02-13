@echo off
REM Start MCP Server - kills existing processes first to avoid port conflicts

echo Stopping any existing Python processes...
taskkill /F /IM python.exe 2>nul
taskkill /F /IM pythonw.exe 2>nul
timeout /t 1 /nobreak >nul

echo Starting MCP Server...
python -m src.mcp_server.server
