param(
    [string]$RepoUrl = "https://github.com/lbox-src/docs.git",
    [string]$Branch = "main",
    [string]$TargetDir = "data/upstream_docs/lbox-src-docs"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
$targetPath = Join-Path $repoRoot $TargetDir
$targetParent = Split-Path -Parent $targetPath

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git is required but was not found in PATH."
}

if (-not (Test-Path $targetParent)) {
    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
}

if (-not (Test-Path $targetPath)) {
    Write-Host "[docs] Cloning upstream docs into $targetPath"
    git clone --branch $Branch --single-branch $RepoUrl $targetPath
} else {
    Write-Host "[docs] Updating existing upstream docs at $targetPath"
    Push-Location $targetPath
    try {
        git fetch origin $Branch
        git checkout $Branch
        git pull --ff-only origin $Branch
    } finally {
        Pop-Location
    }
}

$metaFile = Join-Path $repoRoot "data/upstream_docs/last-sync.txt"
$metaLine = "$(Get-Date -Format s) synced from $RepoUrl#$Branch"
Set-Content -Path $metaFile -Value $metaLine -Encoding UTF8

Write-Host "[docs] Sync complete"
Write-Host "[docs] Source: $RepoUrl"
Write-Host "[docs] Local:  $targetPath"