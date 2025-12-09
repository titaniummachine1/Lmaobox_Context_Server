# Auto-Deploy Prototypes to Lmaobox
# Watches for file changes and deploys automatically

$SourceDir = "c:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server\prototypes"
$TargetDir = "C:\Users\Terminatort8000\AppData\Local\lua"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   Lmaobox Auto-Deploy Watcher" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $SourceDir" -ForegroundColor Yellow
Write-Host "Target: $TargetDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "Watching for .lua file changes..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

# Ensure target directory exists
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    Write-Host "[CREATED] Target directory: $TargetDir" -ForegroundColor Magenta
}

# Initial deployment
Write-Host "[INITIAL] Deploying all .lua files..." -ForegroundColor Cyan
Get-ChildItem -Path $SourceDir -Filter "*.lua" | ForEach-Object {
    $dest = Join-Path $TargetDir $_.Name
    Copy-Item $_.FullName -Destination $dest -Force
    Write-Host "[DEPLOYED] $($_.Name)" -ForegroundColor Green
}
Write-Host ""

# Create file watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SourceDir
$watcher.Filter = "*.lua"
$watcher.IncludeSubdirectories = $false
$watcher.EnableRaisingEvents = $true

# Debounce helper
$lastDeployTime = @{}
$debounceMs = 500

# Deploy function
$deploy = {
    param($source)
    
    $fileName = [System.IO.Path]::GetFileName($source)
    $dest = Join-Path $TargetDir $fileName
    
    # Debounce check
    $now = (Get-Date).Ticks / 10000
    if ($lastDeployTime.ContainsKey($fileName)) {
        $elapsed = $now - $lastDeployTime[$fileName]
        if ($elapsed -lt $debounceMs) {
            return
        }
    }
    $lastDeployTime[$fileName] = $now
    
    try {
        Copy-Item $source -Destination $dest -Force
        $time = Get-Date -Format "HH:mm:ss"
        Write-Host "[$time] [UPDATED] $fileName" -ForegroundColor Yellow
    }
    catch {
        Write-Host "[ERROR] Failed to deploy $fileName : $_" -ForegroundColor Red
    }
}

# Event handlers
$onChange = Register-ObjectEvent $watcher "Changed" -Action {
    & $event.MessageData $EventArgs.FullPath
} -MessageData $deploy

$onCreate = Register-ObjectEvent $watcher "Created" -Action {
    & $event.MessageData $EventArgs.FullPath
} -MessageData $deploy

$onRename = Register-ObjectEvent $watcher "Renamed" -Action {
    $newPath = $EventArgs.FullPath
    & $event.MessageData $newPath
} -MessageData $deploy

# Keep running
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    # Cleanup
    Unregister-Event -SourceIdentifier $onChange.Name
    Unregister-Event -SourceIdentifier $onCreate.Name
    Unregister-Event -SourceIdentifier $onRename.Name
    $watcher.Dispose()
    Write-Host ""
    Write-Host "[STOPPED] Auto-deploy watcher" -ForegroundColor Red
}
