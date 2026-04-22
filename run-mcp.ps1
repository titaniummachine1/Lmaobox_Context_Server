# run-mcp.ps1
# Auto-builds lmaobox-mcp.exe from source if missing or stale, then runs it.
# This is the MCP server entry point — mcp.json points here, not at the binary.
#
# Security model: no binary is stored in git. This script compiles from auditable
# Go source on the local machine using the local Go toolchain. Anyone can read
# main.go before this runs.

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exePath = Join-Path $scriptDir "lmaobox-mcp.exe"

function NeedsBuild {
    if (-not (Test-Path $exePath)) {
        return $true
    }
    $exeTime = (Get-Item $exePath).LastWriteTime
    $goFiles = Get-ChildItem $scriptDir -Filter "*.go" -File
    foreach ($f in $goFiles) {
        if ($f.LastWriteTime -gt $exeTime) {
            return $true
        }
    }
    return $false
}

if (NeedsBuild) {
    $goCmd = Get-Command go -ErrorAction SilentlyContinue
    if (-not $goCmd) {
        Write-Error "Go is not installed or not in PATH. Install from: https://go.dev/dl/"
        exit 1
    }

    Write-Host "Building lmaobox-mcp.exe from source..." -ForegroundColor Cyan
    Push-Location $scriptDir
    try {
        & go build -o lmaobox-mcp.exe .
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Build failed. Check Go source for errors."
            exit 1
        }
    }
    finally {
        Pop-Location
    }
    Write-Host "Build complete." -ForegroundColor Green
}

# Run the MCP server. Stdio is inherited from this process (MCP client connects here).
& $exePath
exit $LASTEXITCODE
