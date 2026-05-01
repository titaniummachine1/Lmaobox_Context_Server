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
        $Settings | Add-Member -MemberType NoteProperty -Name modelContextProtocol -Value (@{ servers = @{} })
    }
    if (-not $Settings.modelContextProtocol.servers) {
        $Settings.modelContextProtocol | Add-Member -MemberType NoteProperty -Name servers -Value @{}
    }

    $Settings.modelContextProtocol.servers."lmaobox-context" = $ServerConfig

    # Ensure Lua workspace settings include the repo "types" library so Sumneko/Other LSPs use our annotations
    if (-not $Settings.PSObject.Properties['Lua']) {
        $Settings | Add-Member -MemberType NoteProperty -Name Lua -Value @{}
    }
    if (-not $Settings.Lua.PSObject.Properties['workspace']) {
        $Settings.Lua | Add-Member -MemberType NoteProperty -Name workspace -Value @{}
    }
    if (-not $Settings.Lua.workspace.PSObject.Properties['library']) {
        $Settings.Lua.workspace | Add-Member -MemberType NoteProperty -Name library -Value @{}
    }

    # Use workspace-relative key so it works for clones and VS Code variable expansion
    $libraryKey = '${workspaceFolder}/types'
    # Also add a global installed path under %LOCALAPPDATA% so the packaged annotations are available for any workspace
    $globalBase = Join-Path $env:LOCALAPPDATA "lmaobox-context-server"
    $globalTypesPath = Join-Path $globalBase "types"
    $globalTypesPath = $globalTypesPath -replace '\\', '/'
    # Copy existing library entries where present (ConvertFrom-Json gives PSCustomObject)
    $currentLib = @{}
    if ($Settings.Lua.workspace.library) {
        foreach ($p in $Settings.Lua.workspace.library.PSObject.Properties) {
            $currentLib[$p.Name] = $p.Value
        }
    }
    $currentLib[$libraryKey] = $true
    if (Test-Path $globalTypesPath) {
        $currentLib[$globalTypesPath] = $true
    }
    $Settings.Lua.workspace.library = $currentLib

    $Settings | ConvertTo-Json -Depth 64 | Out-File $EditorConfigPath -Encoding UTF8
    Write-Host "Done! Lua workspace library updated and MCP server configured. Restart your editor now."
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
