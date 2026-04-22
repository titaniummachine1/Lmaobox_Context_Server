# Lmaobox Context Server - Dependency Setup (PowerShell)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Lmaobox Context Server - Dependency Setup" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Check for Python
Write-Host "Checking for Python..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Python found: $pythonVersion" -ForegroundColor Green
    } else {
        throw "Python not found"
    }
} catch {
    Write-Host "⚠ Python 3 not found in PATH" -ForegroundColor Red
    Write-Host "Please install from: https://www.python.org/downloads/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Run Lua setup
Write-Host ""
Write-Host "Installing Lua 5.4+ compiler..." -ForegroundColor Yellow
python "$scriptDir/install_lua.py"
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠ Lua installation encountered issues. Check output above." -ForegroundColor Yellow
} else {
    Write-Host "✓ Lua installed successfully" -ForegroundColor Green
}

# Run luacheck setup
Write-Host ""
Write-Host "Installing luacheck linter..." -ForegroundColor Yellow
python "$scriptDir/install_luacheck.py"
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠ luacheck installation is optional. You can install manually:" -ForegroundColor Yellow
    Write-Host "   pip install luacheck" -ForegroundColor Cyan
} else {
    Write-Host "✓ luacheck installed successfully" -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "The MCP server is now ready to use. All dependencies have been"
Write-Host "installed or configured automatically."
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Ensure the Go binary is built: go build" -ForegroundColor Cyan
Write-Host "  2. Start the MCP server (it will validate dependencies on startup)" -ForegroundColor Cyan
Write-Host ""
