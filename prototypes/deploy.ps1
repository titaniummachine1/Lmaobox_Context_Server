# Deploy Single Script to Lmaobox
# Triggered by "Run on Save" extension

param(
    [string]$FilePath
)

$TargetDir = "C:\Users\Terminatort8000\AppData\Local\lua"

# If no file specified, deploy all .lua files in prototypes
if (-not $FilePath) {
    $SourceDir = Split-Path -Parent $PSCommandPath
    Get-ChildItem -Path $SourceDir -Filter "*.lua" | ForEach-Object {
        $dest = Join-Path $TargetDir $_.Name
        Copy-Item $_.FullName -Destination $dest -Force
        Write-Host "[DEPLOYED] $($_.Name)" -ForegroundColor Green
    }
    exit 0
}

# Deploy specific file
if ($FilePath -match "\.lua$") {
    $fileName = [System.IO.Path]::GetFileName($FilePath)
    $dest = Join-Path $TargetDir $fileName
    
    try {
        # Ensure target directory exists
        if (-not (Test-Path $TargetDir)) {
            New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
        }
        
        Copy-Item $FilePath -Destination $dest -Force
        $time = Get-Date -Format "HH:mm:ss"
        Write-Host "[$time] Deployed: $fileName" -ForegroundColor Cyan
    }
    catch {
        Write-Host "[ERROR] Failed to deploy $fileName : $_" -ForegroundColor Red
        exit 1
    }
}
