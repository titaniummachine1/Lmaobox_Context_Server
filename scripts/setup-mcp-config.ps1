#requires -Version 5.1
<#
.SYNOPSIS
    Configure the Lmaobox Context MCP server for VS Code / Cursor / Claude.

.DESCRIPTION
    This script generates the correct MCP configuration for your VS Code or Cursor
    editor, using the absolute path to this repository. After running, paste the
    generated config into your editor's settings.json under the "modelContextProtocol"
    section.

    It can optionally write directly to your editor config if you specify the path.

.PARAMETER EditorConfigPath
    Optional: Path to your VS Code settings.json or Cursor equivalent.
    If provided, the config will be auto-inserted into the file.
    Example: $env:APPDATA\Code\User\settings.json

.PARAMETER OutputFile
    Optional: Save the generated config to this file instead of stdout.

.PARAMETER LauncherType
    Which launcher to use: "python" (default) or "exe".
    - "python": Uses launch_mcp.py (requires Python installed)
    - "exe": Uses lmaobox-context-server.exe (faster, pre-built)

.EXAMPLE
    # Display config for manual copy-paste
    .\setup-mcp-config.ps1

    # Auto-inject into VS Code settings
    .\setup-mcp-config.ps1 -EditorConfigPath "$env:APPDATA\Code\User\settings.json"

    # Auto-inject into Cursor settings
    .\setup-mcp-config.ps1 -EditorConfigPath "$env:APPDATA\Cursor\User\settings.json"

    # Save to file for review
    .\setup-mcp-config.ps1 -OutputFile "mcp-config-generated.json"
#>
param(
    [string]$EditorConfigPath,
    [string]$OutputFile,
    [ValidateSet("python", "exe")]
    [string]$LauncherType = "python"
)

# Get the repo root (parent of scripts)
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$LauncherPath = Join-Path $RepoRoot "launch_mcp.py"

if ($LauncherType -eq "exe") {
    $LauncherPath = Join-Path $RepoRoot "lmaobox-context-server.exe"
}

# Convert to forward slashes for JSON compatibility
$LauncherPath = $LauncherPath -replace '\\', '/'

# Build the MCP config
$Config = @{
    servers = @{
        "lmaobox-context" = @{
            type    = "stdio"
            command = if ($LauncherType -eq "python") { "python" } else { $LauncherPath }
            args    = if ($LauncherType -eq "python") { @($LauncherPath) } else { @() }
            cwd     = $RepoRoot -replace '\\', '/'
            disabled = $false
        }
    }
} | ConvertTo-Json -Depth 10

# Strip the outer "servers" wrapper if it exists and just return the inner object for VS Code
$MCPConfig = @{
    "lmaobox-context" = @{
        type    = "stdio"
        command = if ($LauncherType -eq "python") { "python" } else { $LauncherPath }
        args    = if ($LauncherType -eq "python") { @($LauncherPath) } else { @() }
        cwd     = $RepoRoot -replace '\\', '/'
        disabled = $false
    }
} | ConvertTo-Json -Depth 10

$VSCodeTemplate = @"
// Add this to your VS Code settings.json under "modelContextProtocol.servers"
{
    "modelContextProtocol.servers": {
        $MCPConfig
    }
}
"@

# Output or save
if ($OutputFile) {
    $MCPConfig | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "✓ Config saved to: $OutputFile"
    Write-Host ""
    Write-Host "Launcher: $($LauncherType)"
    Write-Host "Launcher path: $LauncherPath"
    Write-Host "Repo root: $RepoRoot"
}
elseif ($EditorConfigPath) {
    Write-Host "Installing MCP config into: $EditorConfigPath"
    
    if (-not (Test-Path $EditorConfigPath)) {
        Write-Host "ERROR: Settings file not found: $EditorConfigPath"
        Write-Host ""
        Write-Host "Try one of these paths instead:"
        Write-Host "  VS Code:  $env:APPDATA\Code\User\settings.json"
        Write-Host "  Cursor:   $env:APPDATA\Cursor\User\settings.json"
        exit 1
    }

    # Load existing settings
    try {
        $Settings = Get-Content $EditorConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "ERROR: Could not parse existing settings.json"
        Write-Host "Please ensure it's valid JSON or check the file manually."
        exit 1
    }

    # Ensure modelContextProtocol object exists
    if (-not $Settings.modelContextProtocol) {
        $Settings | Add-Member -NotePropertyName "modelContextProtocol" -NotePropertyValue @{ servers = @{} }
    }
    if (-not $Settings.modelContextProtocol.servers) {
        $Settings.modelContextProtocol | Add-Member -NotePropertyName "servers" -NotePropertyValue @{}
    }

    # Merge in new server config
    $Settings.modelContextProtocol.servers."lmaobox-context" = @{
        type    = "stdio"
        command = if ($LauncherType -eq "python") { "python" } else { $LauncherPath }
        args    = if ($LauncherType -eq "python") { @($LauncherPath) } else { @() }
        cwd     = $RepoRoot -replace '\\', '/'
        disabled = $false
    }

    # Save back
    $Settings | ConvertTo-Json -Depth 32 | Out-File -FilePath $EditorConfigPath -Encoding UTF8
    Write-Host "✓ MCP config installed successfully"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Restart your editor (VS Code / Cursor)"
    Write-Host "  2. You should see the 'lmaobox-context' MCP server in the status bar"
    Write-Host ""
    Write-Host "Launcher: $LauncherType"
    Write-Host "Launcher path: $LauncherPath"
    Write-Host "Repo root: $RepoRoot"
}
else {
    Write-Host "Lmaobox Context MCP Server Configuration"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "Copy this into your VS Code / Cursor settings.json under 'modelContextProtocol.servers':"
    Write-Host ""
    Write-Host $MCPConfig
    Write-Host ""
    Write-Host "Settings file locations:"
    Write-Host "  VS Code:  $env:APPDATA\Code\User\settings.json"
    Write-Host "  Cursor:   $env:APPDATA\Cursor\User\settings.json"
    Write-Host ""
    Write-Host "After adding the config, restart your editor and you should see 'lmaobox-context' in the status bar."
    Write-Host ""
    Write-Host "Or run with -EditorConfigPath to auto-install:"
    Write-Host '  .\setup-mcp-config.ps1 -EditorConfigPath "$env:APPDATA\Code\User\settings.json"'
}
