$ErrorActionPreference = "Stop"

$hostName = $env:MCP_HOST
if ([string]::IsNullOrWhiteSpace($hostName)) { $hostName = "127.0.0.1" }

$port = $env:MCP_PORT
if ([string]::IsNullOrWhiteSpace($port)) { $port = "8765" }

$symbol = $env:MCP_TEST_SYMBOL
if ([string]::IsNullOrWhiteSpace($symbol)) { $symbol = "Draw" }

$base = "http://$hostName`:$port"
Write-Host "MCP health @ $base/health"
try {
    $health = Invoke-RestMethod -Uri "$base/health" -TimeoutSec 3
    Write-Host "Health:" ($health | ConvertTo-Json -Compress)
} catch {
    Write-Error "Health check failed: $_"
    exit 1
}

Write-Host "get_types for symbol '$symbol'"
try {
    $resp = Invoke-RestMethod -Uri "$base/get_types?symbol=$symbol" -TimeoutSec 5
    Write-Output ($resp | ConvertTo-Json -Depth 6)
} catch {
    Write-Error "get_types failed: $_"
    exit 1
}

