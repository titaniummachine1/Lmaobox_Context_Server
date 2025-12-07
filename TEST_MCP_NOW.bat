@echo off
cd /d "%~dp0"
echo ================================================================================
echo MCP SERVER TEST
echo ================================================================================
echo.

echo [1] Testing Python imports...
python -c "from src.mcp_server.server import get_types; print('OK: Imports work')" 2>&1
if errorlevel 1 (
    echo FAILED: Python imports broken
    pause
    exit /b 1
)
echo.

echo [2] Testing get_types function...
python -c "from src.mcp_server.server import get_types; r = get_types('Draw'); print('OK: get_types returned:', type(r).__name__); print('Keys:', list(r.keys()) if isinstance(r, dict) else 'not a dict')" 2>&1
echo.

echo [3] Testing MCP stdio protocol...
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}} | python launch_mcp.py 2>&1 | findstr /C:"lmaobox-context" /C:"error"
echo.

echo ================================================================================
echo Test complete! If you see "lmaobox-context" above, the server works!
echo ================================================================================
echo.
echo Now configure in Cursor:
echo 1. Open Cursor Settings
echo 2. Go to: Features -^> Model Context Protocol
echo 3. Click "Edit Config" 
echo 4. Add this JSON (update the path!):
echo.
echo {
echo   "mcpServers": {
echo     "lmaobox-context": {
echo       "command": "python",
echo       "args": ["%~dp0launch_mcp.py"],
echo       "cwd": "%~dp0"
echo     }
echo   }
echo }
echo.
pause
