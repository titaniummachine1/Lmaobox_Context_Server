# Script to download Lua files from GitHub repositories
# Usage: .\download_repos.ps1

$ErrorActionPreference = "Stop"

$baseDir = $PSScriptRoot
$toProcessDir = Join-Path $baseDir "01_TO_PROCESS"

# Ensure directory exists
New-Item -ItemType Directory -Path $toProcessDir -Force | Out-Null

Write-Host "Downloading files from lbox-projectile-aimbot..." -ForegroundColor Cyan

# Projectile aimbot files
$projectileAimbotFiles = @(
    "main.lua",
    "multipoint.lua",
    "playersim.lua",
    "projectile_info.lua",
    "projectilesim.lua",
    "weaponInfo.lua",
    "utils/math.lua",
    "utils/weapon_utils.lua"
)

$projectileAimbotBase = "https://raw.githubusercontent.com/uosq/lbox-projectile-aimbot/main"

foreach ($file in $projectileAimbotFiles) {
    $url = "$projectileAimbotBase/$file"
    $filename = $file.Replace("/", "_")
    $outPath = Join-Path $toProcessDir "projaimbot_$filename"
    
    Write-Host "  Downloading $file..." -NoNewline
    try {
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing
        Write-Host " Done" -ForegroundColor Green
    }
    catch {
        Write-Host " Failed: $_" -ForegroundColor Red
    }
}

Write-Host "`nDownloading files from lmaobox-luas..." -ForegroundColor Cyan

# Lmaobox-luas files - prioritize most useful ones first
$lmaoboxFiles = @(
    "playersim.lua",
    "autobackstab.lua",
    "custom antiaim.lua",
    "player warning.lua",
    "gui lib.lua",
    "nmenu.lua",
    "hook stuff.lua",
    "chams.lua",
    "glow.lua",
    "outline.lua",
    "crosshair.lua",
    "custom hud.lua",
    "gradient backtrack.lua",
    "line tracer.lua",
    "splash radius.lua",
    "sniper rifle dmg.lua",
    "controller helper.lua",
    "med range.lua",
    "sentry.lua",
    "auto sticky delay.lua",
    "auto vote.lua",
    "killsay.lua",
    "chat prefixes.lua",
    "spectator list.lua",
    "world modulation.lua",
    "night mode.lua",
    "transparent chams.lua",
    "transparent doors.lua",
    "3d circles.lua",
    "anticheat.lua",
    "auto holiday punch.lua",
    "auto queue.lua",
    "change aim with weapon.lua",
    "change glow colors.lua",
    "cli event based.lua",
    "fov weapons.lua",
    "heatmaker charge.lua",
    "laggy animations.lua",
    "medieval camera.lua",
    "outline2.lua",
    "priority 10 on medic call.lua",
    "rain.lua",
    "recreated menu.lua",
    "rgb.lua",
    "sakura.lua",
    "smooth dash.lua",
    "smooth dash 2.lua",
    "sniper thing.lua",
    "sniper zoom.lua",
    "snow.lua",
    "spectator list lite.lua",
    "sticky range.lua",
    "stream snipe.lua",
    "sydney extinguisher.lua",
    "thirdperson offset.lua",
    "viewmodel outline.lua",
    "yes.lua",
    "E_NetMessageTypes.lua",
    "aspect ratios.lua"
)

$lmaoboxBase = "https://raw.githubusercontent.com/uosq/lmaobox-luas/main"

foreach ($file in $lmaoboxFiles) {
    $url = "$lmaoboxBase/$file"
    $filename = $file.Replace(" ", "_")
    $outPath = Join-Path $toProcessDir "lmaobox_$filename"
    
    Write-Host "  Downloading $file..." -NoNewline
    try {
        Invoke-WebRequest -Uri $url -OutFile $outPath -UseBasicParsing
        Write-Host " Done" -ForegroundColor Green
    }
    catch {
        Write-Host " Failed: $_" -ForegroundColor Red
    }
}

Write-Host "`nDownload complete!" -ForegroundColor Green
Write-Host "Files are in: $toProcessDir" -ForegroundColor Yellow
