# Kill all Python processes related to MCP server
Write-Host "Finding MCP Python processes..." -ForegroundColor Yellow

# Find all Python processes that might be MCP servers
$processes = Get-Process python -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -and (
        $_.CommandLine -like "*launch_mcp*" -or 
        $_.CommandLine -like "*mcp_stdio*" -or
        $_.CommandLine -like "*lmaobox*" -or
        $_.CommandLine -like "*mcp_server*"
    )
}

if ($processes) {
    Write-Host "Found $($processes.Count) MCP process(es):" -ForegroundColor Red
    $processes | ForEach-Object {
        Write-Host "  PID: $($_.Id) - $($_.CommandLine)" -ForegroundColor Red
    }
    
    Write-Host "`nTerminating MCP processes..." -ForegroundColor Yellow
    $processes | ForEach-Object {
        try {
            Stop-Process -Id $_.Id -Force
            Write-Host "  ✓ Killed process $($_.Id)" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Failed to kill process $($_.Id): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`nWaiting 2 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    # Verify they're gone
    $remaining = Get-Process python -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -and (
            $_.CommandLine -like "*launch_mcp*" -or 
            $_.CommandLine -like "*mcp_stdio*" -or
            $_.CommandLine -like "*lmaobox*" -or
            $_.CommandLine -like "*mcp_server*"
        )
    }
    
    if ($remaining) {
        Write-Host "Warning: $($remaining.Count) process(es) still running:" -ForegroundColor Red
        $remaining | ForEach-Object {
            Write-Host "  PID: $($_.Id)" -ForegroundColor Red
        }
    } else {
        Write-Host "✓ All MCP processes terminated successfully!" -ForegroundColor Green
    }
} else {
    Write-Host "No MCP processes found." -ForegroundColor Green
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Completely close Windsurf (File → Exit)" -ForegroundColor Cyan
Write-Host "2. Wait 10 seconds" -ForegroundColor Cyan
Write-Host "3. Reopen Windsurf" -ForegroundColor Cyan
Write-Host "4. Test the bundle tool" -ForegroundColor Cyan
