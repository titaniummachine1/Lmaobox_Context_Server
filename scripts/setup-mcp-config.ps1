#requires -Version 5.1
param(
    [string]$EditorConfigPath,
    [string]$OutputFile,
    [ValidateSet("python", "exe")]
    [string]$LauncherType = "python"
)

$ScriptPath = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $ScriptPath
$LauncherPath = Join-Path $RepoRoot "launch_mcp.py"

if ($LauncherType -eq "exe") {
    $LauncherPath = Join-Path $RepoRoot "lmaobox-context-server.exe"
}

$LauncherPath = $LauncherPath -replace '\\', '/'
$RepoRootJson = $RepoRoot -replace '\\', '/'

$ServerConfig = @{
    type     = "stdio"
    command  = if ($LauncherType -eq "python") { "python" } else { $LauncherPath }
    args     = if ($LauncherType -eq "python") { @($LauncherPath) } else { @() }
    cwd      = $RepoRootJson
    disabled = $false
}

$MCPConfigObj = @{
    "lmaobox-context" = $ServerConfig
}

$MCPConfigJson = $MCPConfigObj | ConvertTo-Json -Depth 10

if ($OutputFile) {
    $MCPConfigJson | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Cfg saved to: $OutputFile"
}
elseif ($EditorConfigPath) {
    Write-Host "Updating: $EditorConfigPath"
    
    if (-not (Test-Path $EditorConfigPath)) {
        Write-Host "ERROR: File not found"
        Write-Host "Try: $env:APPDATA\Code\User\settings.json"
        exit 1
    }

    $Settings = Get-Content $EditorConfigPath -Raw | ConvertFrom-Json
    
    if (-not $Settings.modelContextProtocol) {
        $Settings | Add-Member modelContextProtocol @{ servers = @{} }
    }
    if (-not $Settings.modelContextProtocol.servers) {
        $Settings.modelContextProtocol | Add-Member servers @{}
    }

    $Settings.modelContextProtocol.servers."lmaobox-context" = $ServerConfig
    $Settings | ConvertTo-Json -Depth 32 | Out-File $EditorConfigPath -Encoding UTF8
    
    Write-Host "Done! Restart your editor now."
}
else {
    Write-Host "Lmaobox Context MCP Configuration"
    Write-Host "==================================="
    Write-Host ""
    Write-Host "Copy this into settings.json under modelContextProtocol.servers:"
    Write-Host ""
    Write-Host $MCPConfigJson
    Write-Host ""
    Write-Host "Settings paths:"
    Write-Host "  VS Code: $env:APPDATA\Code\User\settings.json"
    Write-Host "  Cursor:  $env:APPDATA\Cursor\User\settings.json"
}
