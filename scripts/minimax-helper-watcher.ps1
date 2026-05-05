# ============================================
# Minimax Helper Watcher
# ============================================

. "$PSScriptRoot/utils/logger.ps1"

$config = @{
    WatchPath = ".dev-flow/handoff/to-minimax*.md"
    ResultDir = ".dev-flow/results"
    PollInterval = 5
}

Write-Log "Minimax helper watcher started" "INFO"

while ($true) {
    try {
        $taskFiles = Get-ChildItem $config.WatchPath -ErrorAction SilentlyContinue
        
        foreach ($taskFile in $taskFiles) {
            $taskId = [regex]::Match($taskFile.Name, 'to-minimax-(.+)\.md').Groups[1].Value
            
            Write-Log "Processing minimax task: $taskId" "INFO"
            
            # TODO: 呼叫 minimax API
            # $result = Invoke-MinimaxAPI -TaskFile $taskFile.FullName
            
            Write-Log "TODO: Implement minimax API call" "WARN"
            
            # 暫時刪除檔案避免重複處理
             Remove-Item $taskFile.FullName
        }
        
        Start-Sleep -Seconds $config.PollInterval
        
    } catch {
        Write-Log "Error: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
