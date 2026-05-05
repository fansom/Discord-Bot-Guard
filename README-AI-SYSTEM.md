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
