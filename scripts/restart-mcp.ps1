$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$pidFile = Join-Path $repoRoot ".cache/mcp-server.pid"

$hostName = $env:MCP_HOST
if ([string]::IsNullOrWhiteSpace($hostName)) { $hostName = "127.0.0.1" }
$port = $env:MCP_PORT
if ([string]::IsNullOrWhiteSpace($port)) { $port = "8765" }

# Stop existing server if PID file exists
if (Test-Path $pidFile) {
    $existingPid = Get-Content $pidFile | Select-Object -First 1
    if ($existingPid) {
        $proc = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
        if ($proc) {
            try {
                Stop-Process -Id $existingPid -Force -ErrorAction SilentlyContinue
            } catch { }
        }
    }
    Remove-Item $pidFile -ErrorAction SilentlyContinue
}

# Start new server
Push-Location $repoRoot
try {
    $p = Start-Process -FilePath "python" -ArgumentList "-m","src.mcp_server.server" -WorkingDirectory $repoRoot -PassThru -WindowStyle Hidden
    Set-Content -Path $pidFile -Value $p.Id
    # Optional quick health check (non-blocking)
    Start-Sleep -Milliseconds 400
    try {
        $health = Invoke-RestMethod -Uri "http://$hostName`:$port/health" -TimeoutSec 2
        Write-Host "MCP health:" ($health | ConvertTo-Json -Compress)
    } catch {
        Write-Host "MCP health check failed (will ignore): $_"
    }
} finally {
    Pop-Location
}

