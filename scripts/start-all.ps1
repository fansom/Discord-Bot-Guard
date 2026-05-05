# ============================================
# Start All Watchers
# ============================================

Write-Host "Starting AI Collaboration System..." -ForegroundColor Cyan
Write-Host ""

$watchers = @(
    "codex-designer-watcher-complete.ps1",
    "claude-task-watcher-complete.ps1",
    "codex-verification-watcher-complete.ps1",
    "codex-task-watcher-complete.ps1",
    "minimax-helper-watcher-complete.ps1"
)

foreach ($watcher in $watchers) {
    $scriptPath = Join-Path $PSScriptRoot $watcher
    if (-not (Test-Path $scriptPath)) {
        Write-Host "✗ Missing: $watcher" -ForegroundColor Red
        continue
    }

    Start-Process powershell -ArgumentList "-NoExit", "-File", $scriptPath
    Write-Host "✓ Started: $watcher" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "All watchers started!" -ForegroundColor Green
Write-Host "Press any key to exit (watchers will continue running)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
