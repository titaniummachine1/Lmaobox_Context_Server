$ErrorActionPreference = "Stop"

# Resolve repo root relative to this script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")

Write-Host "Starting MCP server from $repoRoot"
Push-Location $repoRoot
try {
    python -m src.mcp_server.server
} finally {
    Pop-Location
}

