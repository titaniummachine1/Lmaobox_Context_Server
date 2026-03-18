param(
    [switch]$SkipNodeInstall,
    [switch]$SkipLuaInstall,
    [switch]$SkipDocsFetch,
    [switch]$RunWebRefresh
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' not found in PATH."
    }
}

function Resolve-PythonCommand {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        return @{ Command = "py"; PrefixArgs = @("-3") }
    }

    if (Get-Command python -ErrorAction SilentlyContinue) {
        return @{ Command = "python"; PrefixArgs = @() }
    }

    throw "Python 3.9+ is required but was not found."
}

Write-Host "==========================================="
Write-Host " Lmaobox Context MCP - Bootstrap Installer "
Write-Host "==========================================="
Write-Host "Repo root: $repoRoot"

Require-Command git
$pythonCmd = Resolve-PythonCommand

function Invoke-Python {
    param(
        [hashtable]$Python,
        [string[]]$Args
    )

    $fullArgs = @()
    if ($Python.PrefixArgs.Count -gt 0) {
        $fullArgs += $Python.PrefixArgs
    }
    $fullArgs += $Args

    & $Python.Command @fullArgs
}

Push-Location $repoRoot
try {
    if (-not $SkipLuaInstall) {
        Write-Host "[setup] Ensuring Lua 5.4+ is available"
        Invoke-Python -Python $pythonCmd -Args @("automations/install_lua.py")
    } else {
        Write-Host "[setup] Skipping Lua setup"
    }

    if (-not $SkipNodeInstall) {
        Require-Command npm
        Write-Host "[setup] Installing Node dependencies in automations/"
        Push-Location "automations"
        try {
            if (Test-Path "package-lock.json") {
                npm ci
            } else {
                npm install
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "[setup] Skipping Node dependency install"
    }

    if (-not $SkipDocsFetch) {
        Write-Host "[setup] Syncing upstream docs repository"
        & "$repoRoot\scripts\fetch-upstream-docs.ps1"
    } else {
        Write-Host "[setup] Skipping upstream docs fetch"
    }

    if ($RunWebRefresh) {
        Require-Command node
        Write-Host "[setup] Running website crawler refresh"
        node automations/refresh-docs.js
    } else {
        Write-Host "[setup] Website refresh not requested (use -RunWebRefresh)"
    }

    Write-Host ""
    Write-Host "[done] Bootstrap complete"
    Write-Host "[next] Configure MCP server command to:"
    Write-Host "       python launch_mcp.py"
    Write-Host "[next] CWD should be:"
    Write-Host "       $repoRoot"
} finally {
    Pop-Location
}