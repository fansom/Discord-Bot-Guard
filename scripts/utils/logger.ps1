# ============================================
# Logger Utility
# ============================================

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # 輸出到控制台
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Green" }
        "DEBUG" { "Cyan" }
        default { "White" }
    }
    Write-Host $logMessage -ForegroundColor $color
    
    # 寫入日誌檔案
    $logDir = ".dev-flow/logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $logFile = "$logDir/$(Get-Date -Format 'yyyy-MM-dd').log"
    $logMessage | Out-File $logFile -Append -Encoding UTF8
}

