# ============================================
# Verification Watcher - Quality Checker
# ============================================

. "$PSScriptRoot/utils/logger.ps1"

$config = @{
    WatchPath = ".dev-flow/handoff/to-verification*.md"
    ResultDir = ".dev-flow/verification"
    PollInterval = 5
}

Write-Log "Verification watcher started" "INFO"

while ($true) {
    try {
        $verificationFiles = Get-ChildItem $config.WatchPath -ErrorAction SilentlyContinue
        
        foreach ($verificationFile in $verificationFiles) {
            $taskId = [regex]::Match($verificationFile.Name, 'to-verification-(.+)\.md').Groups[1].Value
            
            Write-Log "Verifying task: $taskId" "INFO"
            
            # TODO: 呼叫 Codex 驗證
            # $verification = Invoke-CodexVerification -TaskId $taskId
            
            Write-Log "TODO: Implement Codex verification" "WARN"
            
            # 暫時刪除檔案避免重複處理
            # Remove-Item $verificationFile.FullName
        }
        
        Start-Sleep -Seconds $config.PollInterval
        
    } catch {
        Write-Log "Error: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
