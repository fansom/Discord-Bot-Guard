# ============================================
# AI Collaboration System - 一鍵初始化腳本
# ============================================
# 功能: 自動創建所有必要的目錄、配置檔、監控腳本
# 使用: .\init-ai-collaboration-system.ps1
# ============================================

param(
    [string]$ProjectPath = "D:\project\Discord-Bot-Guard",
    [switch]$Force = $false
)

Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   AI Collaboration System - Initialization Script   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────
# 1. 檢查專案路徑
# ─────────────────────────────────────────

if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ 專案路徑不存在: $ProjectPath" -ForegroundColor Red
    Write-Host "請修改腳本中的 ProjectPath 參數或建立該目錄" -ForegroundColor Yellow
    exit 1
}

Set-Location $ProjectPath
Write-Host "✅ 專案路徑: $ProjectPath" -ForegroundColor Green
Write-Host ""

# ─────────────────────────────────────────
# 2. 創建目錄結構
# ─────────────────────────────────────────

Write-Host "📁 創建目錄結構..." -ForegroundColor Yellow

$directories = @(
    ".dev-flow",
    ".dev-flow/tasks",
    ".dev-flow/handoff",
    ".dev-flow/verification",
    ".dev-flow/results",
    ".dev-flow/logs",
    ".dev-flow/templates",
    ".dev-flow/archive",
    "scripts",
    "scripts/utils"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  ✓ Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  - Exists: $dir" -ForegroundColor Gray
    }
}

Write-Host ""

# ─────────────────────────────────────────
# 3. 創建配置檔案
# ─────────────────────────────────────────

Write-Host "⚙️  創建配置檔案..." -ForegroundColor Yellow

# 3.1 config.json (修正 Here-String 語法)
$configJson = @'
{
  "version": "1.0.0",
  "system": {
    "poll_interval_seconds": 5,
    "max_retries": 3,
    "api_timeout_seconds": 60,
    "log_retention_days": 30
  },
  "ai_agents": {
    "codex": {
      "model": "o1-preview",
      "max_tokens": 4000,
      "temperature": 1
    },
    "claude_code": {
      "timeout_minutes": 10,
      "rate_limit_per_day": 25,
      "reset_time": "23:10"
    },
    "minimax": {
      "model": "minimax-m2.7",
      "max_tokens": 2000,
      "context_limit": 10000
    }
  },
  "verification": {
    "criteria": {
      "requirements_compliance": 40,
      "code_quality": 25,
      "test_coverage": 20,
      "documentation": 10,
      "security": 5
    },
    "thresholds": {
      "approved": 75,
      "revision_needed": 60
    }
  },
  "paths": {
    "spec_file": ".dev-flow/spec.md",
    "tasks_dir": ".dev-flow/tasks",
    "handoff_dir": ".dev-flow/handoff",
    "verification_dir": ".dev-flow/verification",
    "results_dir": ".dev-flow/results",
    "logs_dir": ".dev-flow/logs"
  }
}
'@

$configJson | Out-File ".dev-flow/config.json" -Encoding UTF8 -Force
Write-Host "  ✓ Created: .dev-flow/config.json" -ForegroundColor Green

# 3.2 task-status.json
$currentDate = Get-Date -Format 'o'
$taskStatusTemplate = @'
{
  "version": "1.0",
  "last_updated": "TIMESTAMP_PLACEHOLDER",
  "statistics": {
    "total_tasks": 0,
    "completed": 0,
    "in_progress": 0,
    "pending": 0,
    "failed": 0,
    "blocked": 0
  },
  "verification_stats": {
    "approved": 0,
    "revision_needed": 0,
    "rejected": 0,
    "avg_quality_score": 0
  },
  "tasks": {}
}
'@

$taskStatusJson = $taskStatusTemplate -replace 'TIMESTAMP_PLACEHOLDER', $currentDate
$taskStatusJson | Out-File ".dev-flow/task-status.json" -Encoding UTF8 -Force
Write-Host "  ✓ Created: .dev-flow/task-status.json" -ForegroundColor Green

# 3.3 .env.example
$envExample = @'
# OpenAI API Key (用於 Codex)
OPENAI_API_KEY=sk-proj-YOUR_KEY_HERE

# NVIDIA API Key (用於 minimax)
NVIDIA_API_KEY=nvapi-YOUR_KEY_HERE

# Anthropic API Key (選用，若需要直接呼叫 Claude API)
ANTHROPIC_API_KEY=sk-ant-YOUR_KEY_HERE
'@

$envExample | Out-File ".env.example" -Encoding UTF8 -Force
Write-Host "  ✓ Created: .env.example" -ForegroundColor Green

# 3.4 spec.md 範本
$specDate = Get-Date -Format 'yyyy-MM-dd'
$specTemplateRaw = @'
---
version: 1.0
created: DATE_PLACEHOLDER
updated: DATE_PLACEHOLDER
author: Your Name
---

# 專案需求規格

## Feature: [在此填寫功能名稱]

### Description
[功能描述]

### Requirements
- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3

### Technical Constraints
- Technology: Node.js 18+
- Database: PostgreSQL 14+
- Framework: Express.js

### Priority
- P0 (Critical)

### Acceptance Criteria
1. [驗收條件 1]
2. [驗收條件 2]

### Notes
[額外說明]
'@

$specTemplate = $specTemplateRaw -replace 'DATE_PLACEHOLDER', $specDate
$specTemplate | Out-File ".dev-flow/spec.md" -Encoding UTF8 -Force
Write-Host "  ✓ Created: .dev-flow/spec.md (template)" -ForegroundColor Green

Write-Host ""

# ─────────────────────────────────────────
# 4. 創建工具函數
# ─────────────────────────────────────────

Write-Host "🔧 創建工具函數..." -ForegroundColor Yellow

# 4.1 logger.ps1
$utilsLogger = @'
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

Export-ModuleMember -Function Write-Log
'@

$utilsLogger | Out-File "scripts/utils/logger.ps1" -Encoding UTF8 -Force
Write-Host "  ✓ Created: scripts/utils/logger.ps1" -ForegroundColor Green

Write-Host ""

# ─────────────────────────────────────────
# 5. 創建監控腳本
# ─────────────────────────────────────────

Write-Host "📜 創建監控腳本..." -ForegroundColor Yellow

# 5.1 file-watcher.ps1
$fileWatcher = @'
# ============================================
# File Watcher - Spec Monitor
# ============================================

. "$PSScriptRoot/utils/logger.ps1"

$config = @{
    WatchPath = ".dev-flow/spec.md"
    OutputDir = ".dev-flow/tasks"
    HandoffDir = ".dev-flow/handoff"
    PollInterval = 5
}

$script:lastHash = $null

Write-Log "File watcher started - monitoring spec.md" "INFO"

while ($true) {
    try {
        if (-not (Test-Path $config.WatchPath)) {
            Start-Sleep -Seconds $config.PollInterval
            continue
        }
        
        $currentHash = (Get-FileHash $config.WatchPath -Algorithm MD5).Hash
        
        if ($currentHash -ne $script:lastHash) {
            Write-Log "Spec change detected!" "INFO"
            
            # TODO: 呼叫 Codex API 分析需求
            # $specContent = Get-Content $config.WatchPath -Raw
            # $tasks = Invoke-CodexAnalysis -SpecContent $specContent
            
            Write-Log "TODO: Implement Codex API call" "WARN"
            
            $script:lastHash = $currentHash
        }
        
        Start-Sleep -Seconds $config.PollInterval
        
    } catch {
        Write-Log "Error: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
'@

$fileWatcher | Out-File "scripts/file-watcher.ps1" -Encoding UTF8 -Force
Write-Host "  ✓ Created: scripts/file-watcher.ps1" -ForegroundColor Green

# 5.2 claude-task-watcher.ps1
$claudeWatcher = @'
# ============================================
# Claude Task Watcher
# ============================================

. "$PSScriptRoot/utils/logger.ps1"

$config = @{
    WatchPath = ".dev-flow/handoff/to-claude*.md"
    PollInterval = 5
}

Write-Log "Claude task watcher started" "INFO"

while ($true) {
    try {
        $taskFiles = Get-ChildItem $config.WatchPath -ErrorAction SilentlyContinue
        
        foreach ($taskFile in $taskFiles) {
            $taskId = [regex]::Match($taskFile.Name, 'to-claude-(.+)\.md').Groups[1].Value
            
            Write-Log "Processing task: $taskId" "INFO"
            
            # TODO: 呼叫 Claude Code
            # $result = Invoke-ClaudeCode -TaskFile $taskFile.FullName
            
            Write-Log "TODO: Implement Claude Code execution" "WARN"
            
            # 暫時刪除檔案避免重複處理
            # Remove-Item $taskFile.FullName
        }
        
        Start-Sleep -Seconds $config.PollInterval
        
    } catch {
        Write-Log "Error: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
'@

$claudeWatcher | Out-File "scripts/claude-task-watcher.ps1" -Encoding UTF8 -Force
Write-Host "  ✓ Created: scripts/claude-task-watcher.ps1" -ForegroundColor Green

# 5.3 verification-watcher.ps1
$verificationWatcher = @'
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
'@

$verificationWatcher | Out-File "scripts/verification-watcher.ps1" -Encoding UTF8 -Force
Write-Host "  ✓ Created: scripts/verification-watcher.ps1" -ForegroundColor Green

# 5.4 codex-task-watcher.ps1
$codexWatcher = @'
# ============================================
# Codex Task Watcher - Feedback Processor
# ============================================

. "$PSScriptRoot/utils/logger.ps1"

$config = @{
    WatchPath = ".dev-flow/handoff/to-codex*.md"
    PollInterval = 5
}

Write-Log "Codex feedback watcher started" "INFO"

while ($true) {
    try {
        $feedbackFiles = Get-ChildItem $config.WatchPath -ErrorAction SilentlyContinue
        
        foreach ($feedbackFile in $feedbackFiles) {
            $taskId = [regex]::Match($feedbackFile.Name, 'to-codex-(.+)\.md').Groups[1].Value
            
            Write-Log "Processing feedback: $taskId" "INFO"
            
            # TODO: 呼叫 Codex 決策下一步
            # $decision = Invoke-CodexDecision -FeedbackFile $feedbackFile.FullName
            
            Write-Log "TODO: Implement Codex decision logic" "WARN"
            
            # 暫時刪除檔案避免重複處理
            # Remove-Item $feedbackFile.FullName
        }
        
        Start-Sleep -Seconds $config.PollInterval
        
    } catch {
        Write-Log "Error: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
'@

$codexWatcher | Out-File "scripts/codex-task-watcher.ps1" -Encoding UTF8 -Force
Write-Host "  ✓ Created: scripts/codex-task-watcher.ps1" -ForegroundColor Green

# 5.5 minimax-helper-watcher.ps1
$minimaxWatcher = @'
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
            # Remove-Item $taskFile.FullName
        }
        
        Start-Sleep -Seconds $config.PollInterval
        
    } catch {
        Write-Log "Error: $_" "ERROR"
        Start-Sleep -Seconds $config.PollInterval
    }
}
'@

$minimaxWatcher | Out-File "scripts/minimax-helper-watcher.ps1" -Encoding UTF8 -Force
Write-Host "  ✓ Created: scripts/minimax-helper-watcher.ps1" -ForegroundColor Green

# 5.6 start-all.ps1
$startAll = @'
# ============================================
# Start All Watchers
# ============================================

Write-Host "Starting AI Collaboration System..." -ForegroundColor Cyan
Write-Host ""

$watchers = @(
    "file-watcher.ps1",
    "claude-task-watcher.ps1",
    "verification-watcher.ps1",
    "codex-task-watcher.ps1",
    "minimax-helper-watcher.ps1"
)

foreach ($watcher in $watchers) {
    $scriptPath = Join-Path $PSScriptRoot $watcher
    Start-Process powershell -ArgumentList "-NoExit", "-File", $scriptPath
    Write-Host "✓ Started: $watcher" -ForegroundColor Green
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "All watchers started!" -ForegroundColor Green
Write-Host "Press any key to exit (watchers will continue running)..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

$startAll | Out-File "scripts/start-all.ps1" -Encoding UTF8 -Force
Write-Host "  ✓ Created: scripts/start-all.ps1" -ForegroundColor Green

Write-Host ""

# ─────────────────────────────────────────
# 6. 創建模板檔案
# ─────────────────────────────────────────

Write-Host "📋 創建模板檔案..." -ForegroundColor Yellow

# 6.1 to-claude-template.md
$toClaudeTemplate = @'
---
task_id: task-XXX
task_type: development
priority: P0
estimated_time: 15 min
dependencies: []
---

# Task: [任務標題]

## Background
[背景說明]

## Objectives
- [ ] Objective 1
- [ ] Objective 2

## Technical Specifications

### Input
- File: [輸入檔案]

### Output
- Files to create:
  * src/module/file.js
  * tests/module/file.test.js

### Constraints
- Must use: [技術/函式庫]
- Code style: [代碼風格要求]

## Implementation Guide
[實作提示]

## Testing Requirements
- Unit tests with Jest
- Coverage > 80%
'@

$toClaudeTemplate | Out-File ".dev-flow/templates/to-claude-template.md" -Encoding UTF8 -Force
Write-Host "  ✓ Created: .dev-flow/templates/to-claude-template.md" -ForegroundColor Green

# 6.2 to-verification-template.md
$toVerificationTemplate = @'
---
task_id: task-XXX
original_task: to-claude-XXX.md
submitted_at: 2024-01-01T10:00:00Z
execution_time: 8.5 min
---

## 🔍 Verification Request

### Original Task Requirements
[原始需求]

### Implementation Summary
[實作摘要]

### Deliverables Checklist
- [x] Item 1
- [x] Item 2

### Changed Files
```json
{
  "created": [],
  "modified": [],
  "deleted": []
}
```

### Test Results
- Total: 12
- Passed: 12
- Coverage: 85%

### Request for Review
Please verify if this implementation meets the task requirements.
'@

$toVerificationTemplate | Out-File ".dev-flow/templates/to-verification-template.md" -Encoding UTF8 -Force
Write-Host "  ✓ Created: .dev-flow/templates/to-verification-template.md" -ForegroundColor Green

Write-Host ""

# ─────────────────────────────────────────
# 7. 創建 .gitignore
# ─────────────────────────────────────────

Write-Host "🔒 創建 .gitignore..." -ForegroundColor Yellow

$gitignore = @'
# Environment variables
.env

# Logs
.dev-flow/logs/*.log
*.log

# Temporary files
.dev-flow/handoff/to-*.md
.dev-flow/results/*
.dev-flow/verification/*

# Node
node_modules/
package-lock.json

# OS
.DS_Store
Thumbs.db
'@

if (-not (Test-Path ".gitignore") -or $Force) {
    $gitignore | Out-File ".gitignore" -Encoding UTF8 -Force
    Write-Host "  ✓ Created: .gitignore" -ForegroundColor Green
} else {
    Write-Host "  - Exists: .gitignore (use -Force to overwrite)" -ForegroundColor Gray
}

Write-Host ""

# ─────────────────────────────────────────
# 8. 創建 README
# ─────────────────────────────────────────

Write-Host "📖 創建 README..." -ForegroundColor Yellow

$readme = @'
# AI Collaboration Development System

多 AI 協作開發系統，透過 Codex、Claude Code、minimax 三層架構實現自動化開發流程。

## 快速開始

### 1. 設定環境變數

```bash
# 複製範例檔案
cp .env.example .env

# 編輯 .env 填入 API Keys
notepad .env
```

### 2. 啟動監控系統

```powershell
# 方式 1: 一鍵啟動所有監控器
.\scripts\start-all.ps1

# 方式 2: 手動啟動個別監控器
.\scripts\file-watcher.ps1
.\scripts\claude-task-watcher.ps1
.\scripts\verification-watcher.ps1
.\scripts\codex-task-watcher.ps1
.\scripts\minimax-helper-watcher.ps1
```

### 3. 編寫需求

編輯 `.dev-flow/spec.md` 填寫功能需求，系統將自動：
1. Codex 分析需求並拆分任務
2. Claude Code 執行開發
3. Codex 驗證品質
4. 自動循環直到完成

## 架構說明

- **Layer 1 (Planner)**: Codex - 需求分析、任務規劃、品質驗證
- **Layer 2 (Executor)**: Claude Code - 核心功能開發
- **Layer 2.5 (Verifier)**: Codex - 品質審查與驗證
- **Layer 3 (Helper)**: minimax - 簡單重複性任務

## 文檔

- [系統分析文件 (SA)](./AI-Collaboration-System-SA.md)
- [系統設計文件 (SD)](./AI-Collaboration-System-SD.md)

## 目錄結構

```
.dev-flow/
├─ spec.md              # 需求規格 (你編輯這個)
├─ tasks/               # Codex 生成的任務
├─ handoff/             # AI 間交接文件
├─ verification/        # 驗證結果
└─ logs/                # 執行日誌

scripts/
├─ file-watcher.ps1
├─ claude-task-watcher.ps1
├─ verification-watcher.ps1
├─ codex-task-watcher.ps1
└─ minimax-helper-watcher.ps1
```

## License

MIT
'@

$readme | Out-File "README-AI-SYSTEM.md" -Encoding UTF8 -Force
Write-Host "  ✓ Created: README-AI-SYSTEM.md" -ForegroundColor Green

Write-Host ""

# ─────────────────────────────────────────
# 9. 完成總結
# ─────────────────────────────────────────

Write-Host "╔═══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              ✅ Initialization Complete!             ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📁 Created Directories:" -ForegroundColor Cyan
Write-Host "   - .dev-flow/ (及所有子目錄)" -ForegroundColor White
Write-Host "   - scripts/ (及工具目錄)" -ForegroundColor White
Write-Host ""

Write-Host "📜 Created Scripts:" -ForegroundColor Cyan
Write-Host "   - file-watcher.ps1" -ForegroundColor White
Write-Host "   - claude-task-watcher.ps1" -ForegroundColor White
Write-Host "   - verification-watcher.ps1" -ForegroundColor White
Write-Host "   - codex-task-watcher.ps1" -ForegroundColor White
Write-Host "   - minimax-helper-watcher.ps1" -ForegroundColor White
Write-Host "   - start-all.ps1" -ForegroundColor White
Write-Host ""

Write-Host "⚙️  Created Configurations:" -ForegroundColor Cyan
Write-Host "   - config.json" -ForegroundColor White
Write-Host "   - task-status.json" -ForegroundColor White
Write-Host "   - .env.example" -ForegroundColor White
Write-Host "   - spec.md (template)" -ForegroundColor White
Write-Host ""

Write-Host "📋 Next Steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1️⃣  設定 API Keys:" -ForegroundColor White
Write-Host "   cp .env.example .env" -ForegroundColor Gray
Write-Host "   notepad .env" -ForegroundColor Gray
Write-Host ""
Write-Host "2️⃣  編寫需求規格:" -ForegroundColor White
Write-Host "   notepad .dev-flow\spec.md" -ForegroundColor Gray
Write-Host ""
Write-Host "3️⃣  啟動監控系統:" -ForegroundColor White
Write-Host "   .\scripts\start-all.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "4️⃣  實作 API 呼叫邏輯:" -ForegroundColor White
Write-Host "   各監控腳本中搜尋 'TODO' 標記" -ForegroundColor Gray
Write-Host ""

Write-Host "📖 Documentation:" -ForegroundColor Cyan
Write-Host "   - README-AI-SYSTEM.md" -ForegroundColor White
Write-Host ""

Write-Host "🎉 系統骨架已建立完成！" -ForegroundColor Green
Write-Host "   現在可以開始實作各監控器的 API 呼叫邏輯" -ForegroundColor Green
Write-Host ""
