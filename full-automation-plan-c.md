# 方案 C：完全自動化工作流設計

**目標：** 從提出需求到所有任務完成，只需人工介入一次（最終 merge）

---

## 核心概念

### 自動化循環引擎

```
您提出需求
    ↓
ChatGPT 產生 spec.md
    ↓
Codex 拆分所有任務 (task-001 ~ task-N)
    ↓
┌─────────────────────────────────────┐
│   自動執行循環 (無需人工介入)        │
│                                     │
│   while (有 ready 任務) {           │
│     Claude Code: 執行任務           │
│         ↓ (自動觸發)                │
│     Codex: 審核                     │
│         ↓ (判斷)                    │
│     if PASS:                        │
│       commit & push                 │
│       標記 done                     │
│       解鎖依賴任務 → ready          │
│     else:                           │
│       退回 Claude Code 修改         │
│   }                                 │
└─────────────────────────────────────┘
    ↓
所有任務完成 (status: done)
    ↓
通知您進行最終 merge
```

---

## 完整檔案結構

```
project-root/
├── .dev-flow/
│   ├── context/
│   │   ├── chatgpt-role.md
│   │   ├── codex-role.md
│   │   └── claude-role.md
│   │
│   ├── handoff/
│   │   ├── to-codex.md
│   │   └── to-claude.md
│   │
│   ├── automation/                    # 新增：自動化引擎
│   │   ├── workflow-state.json        # 工作流狀態追蹤
│   │   ├── cycle-log.md               # 循環執行日誌
│   │   └── completion-report.md       # 最終完成報告
│   │
│   ├── tasks/
│   │   ├── task-001.md
│   │   ├── task-001.context.md
│   │   └── ...
│   │
│   └── spec.md
│
├── .claude/
│   └── commands/
│       ├── check-task.md
│       └── finish-task.md
│
├── scripts/
│   ├── automation-engine.sh           # 新增：自動化主引擎
│   ├── trigger-claude.sh              # 新增：觸發 Claude Code
│   ├── trigger-codex.sh               # 新增：觸發 Codex
│   ├── check-completion.sh            # 新增：檢查所有任務完成
│   └── notify-human.sh                # 新增：通知人工 merge
│
└── src/
    └── ...
```

---

## 自動化引擎設計

### workflow-state.json

追蹤整個工作流的狀態：

```json
{
  "workflow_id": "feature-welcome-member-20260504",
  "status": "running",
  "total_tasks": 4,
  "completed_tasks": 0,
  "current_cycle": 1,
  "current_actor": "claude_code",
  "current_task": "task-001",
  "started_at": "2026-05-04T14:00:00Z",
  "last_updated": "2026-05-04T14:05:00Z",
  "retry_count": 0,
  "max_retries": 3,
  "errors": []
}
```

### automation-engine.sh - 核心引擎

```bash
#!/bin/bash
# 自動化工作流引擎

set -e

WORKFLOW_DIR=".dev-flow/automation"
STATE_FILE="$WORKFLOW_DIR/workflow-state.json"
LOG_FILE="$WORKFLOW_DIR/cycle-log.md"

# 初始化
function init_workflow() {
    echo "🚀 初始化自動化工作流..."
    
    mkdir -p "$WORKFLOW_DIR"
    
    # 計算總任務數
    TOTAL_TASKS=$(ls .dev-flow/tasks/task-*.md 2>/dev/null | wc -l)
    
    # 建立初始狀態
    cat > "$STATE_FILE" << EOF
{
  "workflow_id": "$(date +%Y%m%d-%H%M%S)",
  "status": "running",
  "total_tasks": $TOTAL_TASKS,
  "completed_tasks": 0,
  "current_cycle": 1,
  "current_actor": "claude_code",
  "current_task": null,
  "started_at": "$(date -Iseconds)",
  "last_updated": "$(date -Iseconds)",
  "retry_count": 0,
  "max_retries": 3,
  "errors": []
}
EOF

    # 初始化日誌
    cat > "$LOG_FILE" << EOF
# 自動化工作流執行日誌

開始時間: $(date)
總任務數: $TOTAL_TASKS

---

EOF
    
    echo "✅ 初始化完成"
}

# 主循環
function run_automation_loop() {
    echo ""
    echo "========================================="
    echo "🤖 啟動自動化循環引擎"
    echo "========================================="
    echo ""
    
    CYCLE=1
    
    while true; do
        echo "📊 Cycle #$CYCLE - $(date '+%H:%M:%S')"
        
        # 1. 檢查是否所有任務都完成
        if check_all_tasks_done; then
            echo "🎉 所有任務完成！"
            finalize_workflow
            break
        fi
        
        # 2. 找到下一個 ready 任務
        NEXT_TASK=$(find_next_ready_task)
        
        if [ -z "$NEXT_TASK" ]; then
            echo "⏸️  沒有 ready 任務（可能在等待依賴完成）"
            sleep 30
            continue
        fi
        
        echo "📋 執行任務: $NEXT_TASK"
        update_state "current_task" "$NEXT_TASK"
        update_state "current_cycle" "$CYCLE"
        
        # 3. 觸發 Claude Code 執行
        echo "  → 觸發 Claude Code..."
        update_state "current_actor" "claude_code"
        
        if ! trigger_claude_code "$NEXT_TASK"; then
            handle_error "Claude Code 執行失敗"
            continue
        fi
        
        # 4. 等待 Claude Code 完成
        echo "  → 等待 Claude Code 完成..."
        wait_for_claude_completion "$NEXT_TASK"
        
        # 5. 觸發 Codex 審核
        echo "  → 觸發 Codex 審核..."
        update_state "current_actor" "codex"
        
        if ! trigger_codex_review "$NEXT_TASK"; then
            handle_error "Codex 審核失敗"
            continue
        fi
        
        # 6. 等待 Codex 審核完成
        echo "  → 等待 Codex 審核..."
        wait_for_codex_completion "$NEXT_TASK"
        
        # 7. 檢查審核結果
        REVIEW_STATUS=$(get_review_status "$NEXT_TASK")
        
        if [ "$REVIEW_STATUS" = "PASS" ]; then
            echo "  ✅ 審核通過"
            increment_completed_tasks
            log_cycle "SUCCESS" "$NEXT_TASK" "審核通過並提交"
            
            # 解鎖依賴此任務的其他任務
            unlock_dependent_tasks "$NEXT_TASK"
        else
            echo "  ⚠️  審核未通過，已退回修改"
            log_cycle "RETRY" "$NEXT_TASK" "審核未通過，退回修改"
            # 任務狀態已被 Codex 改回 in_progress
            # 下一個循環會重新執行
        fi
        
        echo ""
        CYCLE=$((CYCLE + 1))
        
        # 短暫延遲避免過於頻繁
        sleep 5
    done
}

# 檢查所有任務是否完成
function check_all_tasks_done() {
    TOTAL=$(ls .dev-flow/tasks/task-*.md 2>/dev/null | wc -l)
    DONE=$(grep -l "status: done" .dev-flow/tasks/task-*.md 2>/dev/null | wc -l)
    
    [ "$TOTAL" -eq "$DONE" ]
}

# 找下一個 ready 任務
function find_next_ready_task() {
    grep -l "status: ready" .dev-flow/tasks/task-*.md 2>/dev/null | sort | head -1 | xargs basename 2>/dev/null | sed 's/.md$//'
}

# 觸發 Claude Code
function trigger_claude_code() {
    local TASK_ID=$1
    
    # 建立 Claude Code 啟動指令
    cat > .dev-flow/automation/claude-command.txt << EOF
讀取 .dev-flow/context/claude-role.md
讀取 .dev-flow/tasks/$TASK_ID.md
讀取 .dev-flow/tasks/$TASK_ID.context.md

按照任務規格執行開發工作。

完成後執行 /finish-task
EOF
    
    # 方式 1：如果 Claude Code 支援 CLI 或 API
    # claude-code --execute .dev-flow/automation/claude-command.txt
    
    # 方式 2：建立觸發檔案，由外部監控程式處理
    echo "$TASK_ID" > .dev-flow/automation/trigger-claude.flag
    
    # 方式 3：透過 MCP 或其他機制觸發
    # （需要額外實作）
    
    return 0
}

# 等待 Claude Code 完成
function wait_for_claude_completion() {
    local TASK_ID=$1
    local TIMEOUT=1800  # 30 分鐘超時
    local ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        # 檢查任務狀態是否變為 review
        TASK_STATUS=$(grep "^status:" ".dev-flow/tasks/$TASK_ID.md" | awk '{print $2}')
        
        if [ "$TASK_STATUS" = "review" ]; then
            echo "  ✓ Claude Code 已完成"
            return 0
        fi
        
        sleep 10
        ELAPSED=$((ELAPSED + 10))
        
        # 每分鐘輸出一次進度
        if [ $((ELAPSED % 60)) -eq 0 ]; then
            echo "  ⏱  已等待 $((ELAPSED / 60)) 分鐘..."
        fi
    done
    
    echo "  ⏰ 超時！"
    return 1
}

# 觸發 Codex 審核
function trigger_codex_review() {
    local TASK_ID=$1
    
    # 建立 Codex 啟動指令
    cat > .dev-flow/automation/codex-command.txt << EOF
讀取 .dev-flow/context/codex-role.md 的「身份 B：審核者」部分
讀取 .dev-flow/handoff/to-codex.md

按照審核流程執行：
1. 讀取任務和上下文包
2. 檢查程式碼變更
3. 執行測試
4. 判斷 PASS/FAIL 並執行相應流程
EOF
    
    # 方式 1：Codex CLI/API
    # codex --execute .dev-flow/automation/codex-command.txt
    
    # 方式 2：建立觸發檔案
    echo "$TASK_ID" > .dev-flow/automation/trigger-codex.flag
    
    return 0
}

# 等待 Codex 審核完成
function wait_for_codex_completion() {
    local TASK_ID=$1
    local TIMEOUT=600  # 10 分鐘超時
    local ELAPSED=0
    
    while [ $ELAPSED -lt $TIMEOUT ]; do
        TASK_STATUS=$(grep "^status:" ".dev-flow/tasks/$TASK_ID.md" | awk '{print $2}')
        
        # 審核完成的狀態：done (通過) 或 in_progress (退回)
        if [ "$TASK_STATUS" = "done" ] || [ "$TASK_STATUS" = "in_progress" ]; then
            echo "  ✓ Codex 審核完成"
            return 0
        fi
        
        sleep 10
        ELAPSED=$((ELAPSED + 10))
    done
    
    echo "  ⏰ 審核超時！"
    return 1
}

# 取得審核結果
function get_review_status() {
    local TASK_ID=$1
    
    # 從任務檔案讀取審核結果
    grep "審核結果：" ".dev-flow/tasks/$TASK_ID.md" | grep -o "PASS\|FAIL" || echo "UNKNOWN"
}

# 解鎖依賴任務
function unlock_dependent_tasks() {
    local COMPLETED_TASK=$1
    
    # 找出所有依賴此任務的其他任務
    for task_file in .dev-flow/tasks/task-*.md; do
        if grep -q "depends_on:.*$COMPLETED_TASK" "$task_file"; then
            # 檢查該任務的所有依賴是否都完成了
            local ALL_DEPS_DONE=true
            local DEPS=$(grep "depends_on:" "$task_file" | sed 's/depends_on: \[\(.*\)\]/\1/' | tr ',' '\n')
            
            for dep in $DEPS; do
                dep=$(echo "$dep" | xargs)  # trim
                if [ "$dep" = "[]" ] || [ -z "$dep" ]; then
                    continue
                fi
                
                local DEP_STATUS=$(grep "^status:" ".dev-flow/tasks/$dep.md" | awk '{print $2}')
                if [ "$DEP_STATUS" != "done" ]; then
                    ALL_DEPS_DONE=false
                    break
                fi
            done
            
            # 如果所有依賴都完成，解鎖此任務
            if [ "$ALL_DEPS_DONE" = true ]; then
                local TASK_ID=$(basename "$task_file" .md)
                local CURRENT_STATUS=$(grep "^status:" "$task_file" | awk '{print $2}')
                
                if [ "$CURRENT_STATUS" = "blocked" ]; then
                    sed -i 's/status: blocked/status: ready/' "$task_file"
                    echo "  🔓 解鎖任務: $TASK_ID"
                    log_cycle "UNLOCK" "$TASK_ID" "所有依賴完成，任務已解鎖"
                fi
            fi
        fi
    done
}

# 更新狀態
function update_state() {
    local KEY=$1
    local VALUE=$2
    
    # 使用 jq 更新（如果有的話）或簡單替換
    if command -v jq &> /dev/null; then
        local TMP=$(mktemp)
        jq ".$KEY = \"$VALUE\" | .last_updated = \"$(date -Iseconds)\"" "$STATE_FILE" > "$TMP"
        mv "$TMP" "$STATE_FILE"
    fi
}

# 增加完成任務計數
function increment_completed_tasks() {
    if command -v jq &> /dev/null; then
        local TMP=$(mktemp)
        jq '.completed_tasks += 1 | .last_updated = "'"$(date -Iseconds)"'"' "$STATE_FILE" > "$TMP"
        mv "$TMP" "$STATE_FILE"
    fi
}

# 記錄循環日誌
function log_cycle() {
    local STATUS=$1
    local TASK_ID=$2
    local MESSAGE=$3
    
    cat >> "$LOG_FILE" << EOF
## Cycle $(jq -r '.current_cycle' "$STATE_FILE" 2>/dev/null || echo "?") - $(date '+%Y-%m-%d %H:%M:%S')

**任務:** $TASK_ID  
**狀態:** $STATUS  
**訊息:** $MESSAGE

---

EOF
}

# 錯誤處理
function handle_error() {
    local ERROR_MSG=$1
    
    echo "❌ 錯誤: $ERROR_MSG"
    log_cycle "ERROR" "N/A" "$ERROR_MSG"
    
    # 增加重試計數
    local RETRY=$(jq -r '.retry_count' "$STATE_FILE" 2>/dev/null || echo "0")
    RETRY=$((RETRY + 1))
    
    update_state "retry_count" "$RETRY"
    
    local MAX_RETRIES=$(jq -r '.max_retries' "$STATE_FILE" 2>/dev/null || echo "3")
    
    if [ "$RETRY" -ge "$MAX_RETRIES" ]; then
        echo "🛑 達到最大重試次數，工作流暫停"
        update_state "status" "paused"
        notify_human "ERROR" "工作流因錯誤暫停，請檢查"
        exit 1
    fi
    
    sleep 60  # 錯誤後等待 1 分鐘再重試
}

# 完成工作流
function finalize_workflow() {
    update_state "status" "completed"
    
    # 產生完成報告
    generate_completion_report
    
    # 通知人工
    notify_human "SUCCESS" "所有任務已完成，請進行最終 merge"
    
    echo ""
    echo "========================================="
    echo "🎉 自動化工作流完成！"
    echo "========================================="
    echo ""
    echo "📊 統計資訊："
    echo "  總任務數: $(jq -r '.total_tasks' "$STATE_FILE")"
    echo "  完成任務: $(jq -r '.completed_tasks' "$STATE_FILE")"
    echo "  總循環數: $(jq -r '.current_cycle' "$STATE_FILE")"
    echo "  開始時間: $(jq -r '.started_at' "$STATE_FILE")"
    echo "  完成時間: $(date -Iseconds)"
    echo ""
    echo "📄 完成報告: .dev-flow/automation/completion-report.md"
    echo ""
    echo "🔍 下一步："
    echo "  1. 檢閱所有 task branch"
    echo "  2. 執行整合測試"
    echo "  3. Merge 到 main"
    echo ""
}

# 產生完成報告
function generate_completion_report() {
    local REPORT_FILE="$WORKFLOW_DIR/completion-report.md"
    
    cat > "$REPORT_FILE" << EOF
# 自動化工作流完成報告

**工作流 ID:** $(jq -r '.workflow_id' "$STATE_FILE")  
**狀態:** 完成 ✅  
**開始時間:** $(jq -r '.started_at' "$STATE_FILE")  
**完成時間:** $(date -Iseconds)

---

## 任務清單

EOF
    
    # 列出所有任務及其狀態
    for task_file in .dev-flow/tasks/task-*.md; do
        TASK_ID=$(basename "$task_file" .md)
        TASK_TITLE=$(grep "^# 任務：" "$task_file" | sed 's/# 任務：//')
        TASK_STATUS=$(grep "^status:" "$task_file" | awk '{print $2}')
        COMMIT_HASH=$(grep "commit hash：" "$task_file" | sed 's/.*commit hash：//' | xargs)
        
        cat >> "$REPORT_FILE" << EOF
### $TASK_ID: $TASK_TITLE

- **狀態:** $TASK_STATUS
- **Commit:** \`$COMMIT_HASH\`
- **Branch:** task/${TASK_ID#task-}

EOF
    done
    
    cat >> "$REPORT_FILE" << EOF

---

## 統計資訊

- **總任務數:** $(jq -r '.total_tasks' "$STATE_FILE")
- **完成任務:** $(jq -r '.completed_tasks' "$STATE_FILE")
- **總循環數:** $(jq -r '.current_cycle' "$STATE_FILE")
- **重試次數:** $(jq -r '.retry_count' "$STATE_FILE")

---

## 下一步行動

### 1. 檢閱 Task Branches

\`\`\`bash
git fetch
git branch -r | grep task/
\`\`\`

### 2. 整合測試（建議）

\`\`\`bash
# 建立測試分支
git checkout -b integration-test

# Merge 所有 task branches
$(for task_file in .dev-flow/tasks/task-*.md; do
    TASK_ID=$(basename "$task_file" .md)
    echo "git merge task/${TASK_ID#task-}"
done)

# 執行測試
npm test  # 或您的測試指令
\`\`\`

### 3. Merge 到 Main

如果測試通過：

\`\`\`bash
git checkout main

# Merge 所有 task branches
$(for task_file in .dev-flow/tasks/task-*.md; do
    TASK_ID=$(basename "$task_file" .md)
    echo "git merge task/${TASK_ID#task-}"
done)

git push
\`\`\`

### 4. 清理

\`\`\`bash
# 刪除 task branches（可選）
$(for task_file in .dev-flow/tasks/task-*.md; do
    TASK_ID=$(basename "$task_file" .md)
    echo "git branch -d task/${TASK_ID#task-}"
    echo "git push origin --delete task/${TASK_ID#task-}"
done)
\`\`\`

---

**報告產生時間:** $(date)
EOF
    
    echo "📄 完成報告已產生"
}

# 通知人工
function notify_human() {
    local TYPE=$1
    local MESSAGE=$2
    
    echo ""
    echo "========================================="
    echo "📧 人工通知"
    echo "========================================="
    echo "類型: $TYPE"
    echo "訊息: $MESSAGE"
    echo "========================================="
    echo ""
    
    # 發送系統通知
    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$MESSAGE\" with title \"自動化工作流 - $TYPE\""
    fi
    
    if command -v notify-send &> /dev/null; then
        notify-send "自動化工作流 - $TYPE" "$MESSAGE"
    fi
    
    # 也可以發送 email、Slack 訊息等
    # send_email "$MESSAGE"
    # send_slack "$MESSAGE"
}

# 主程式
function main() {
    echo "🤖 自動化工作流引擎 v1.0"
    echo ""
    
    # 檢查是否已初始化
    if [ ! -f "$STATE_FILE" ]; then
        init_workflow
    fi
    
    # 啟動循環
    run_automation_loop
}

# 執行主程式
main "$@"
```

---

## 實際使用方式

### 步驟 1：提出需求（人工）

在 ChatGPT Web：

```
【需求】
建立 Discord Bot 的歡迎新成員功能

【已有基礎】
- 資料庫連線
- Bot 架構

【產出要求】
生成 spec.md 到 .dev-flow/spec.md
```

### 步驟 2：拆分任務（Codex 手動執行一次）

對 Codex 說：

```
讀取 .dev-flow/spec.md
按照任務拆分原則建立所有任務
使用 scripts/create-task-context.sh 為每個任務建立上下文包
```

Codex 建立：
- task-001.md ~ task-004.md
- task-001.context.md ~ task-004.context.md

### 步驟 3：啟動自動化引擎（人工執行一次）

```bash
./scripts/automation-engine.sh
```

**然後就不用管了！** ☕

引擎會自動：

```
Cycle #1
  → Claude Code 執行 task-001
  → Codex 審核 task-001
  ✅ PASS → commit & push to task/001
  
Cycle #2
  → Claude Code 執行 task-002
  → Codex 審核 task-002
  ✅ PASS → commit & push to task/002
  
Cycle #3
  → Claude Code 執行 task-003
  → Codex 審核 task-003
  ⚠️  FAIL → 退回修改
  
Cycle #4
  → Claude Code 修改 task-003
  → Codex 重新審核 task-003
  ✅ PASS → commit & push to task/003
  
Cycle #5
  → Claude Code 執行 task-004
  → Codex 審核 task-004
  ✅ PASS → commit & push to task/004

🎉 所有任務完成！
```

### 步驟 4：收到通知（自動）

您會收到：

```
========================================
📧 人工通知
========================================
類型: SUCCESS
訊息: 所有任務已完成，請進行最終 merge
========================================

📊 統計資訊：
  總任務數: 4
  完成任務: 4
  總循環數: 5
  開始時間: 2026-05-04T14:00:00Z
  完成時間: 2026-05-04T15:30:00Z

📄 完成報告: .dev-flow/automation/completion-report.md
```

### 步驟 5：最終 Merge（人工）

```bash
# 1. 檢閱完成報告
cat .dev-flow/automation/completion-report.md

# 2. （可選）整合測試
git checkout -b integration-test
git merge task/001
git merge task/002
git merge task/003
git merge task/004
npm test

# 3. Merge 到 main
git checkout main
git merge task/001
git merge task/002
git merge task/003
git merge task/004
git push

# 4. 清理
git branch -d task/001 task/002 task/003 task/004
```

**完成！** 🎉

---

## 關鍵技術實作

### 如何真正觸發 Claude Code 和 Codex？

#### 方案 1：Claude Code/Codex CLI（最理想）

如果 Claude Code 和 Codex 支援 CLI：

```bash
# trigger_claude_code()
claude-code execute \
    --context .dev-flow/context/claude-role.md \
    --task .dev-flow/tasks/task-001.md \
    --context-pack .dev-flow/tasks/task-001.context.md \
    --on-complete /finish-task

# trigger_codex_review()
codex execute \
    --context .dev-flow/context/codex-role.md \
    --handoff .dev-flow/handoff/to-codex.md \
    --mode review
```

#### 方案 2：MCP Server（推薦）

建立一個 MCP server 作為橋接：

```typescript
// automation-bridge.ts - MCP Server

import { Server } from '@modelcontextprotocol/sdk/server';
import { exec } from 'child_process';

const server = new Server({
  name: 'automation-bridge',
  version: '1.0.0'
});

// 觸發 Claude Code 的 tool
server.tool('trigger_claude_code', async (args) => {
  const { taskId } = args;
  
  // 方式 A：透過 API
  const response = await fetch('https://api.claude.ai/v1/code/execute', {
    method: 'POST',
    body: JSON.stringify({
      context: readFile('.dev-flow/context/claude-role.md'),
      task: readFile(`.dev-flow/tasks/${taskId}.md`),
      contextPack: readFile(`.dev-flow/tasks/${taskId}.context.md`)
    })
  });
  
  return { status: 'triggered', taskId };
});

// 觸發 Codex 的 tool
server.tool('trigger_codex', async (args) => {
  const { taskId } = args;
  
  // 透過 Codex API
  const response = await fetch('codex-api-endpoint', {
    method: 'POST',
    body: JSON.stringify({
      action: 'review',
      handoff: readFile('.dev-flow/handoff/to-codex.md')
    })
  });
  
  return { status: 'triggered', taskId };
});
```

然後在 automation-engine.sh 中：

```bash
trigger_claude_code() {
    local TASK_ID=$1
    
    # 透過 MCP 觸發
    echo '{"taskId": "'$TASK_ID'"}' | \
        mcp-client call automation-bridge trigger_claude_code
}
```

#### 方案 3：檔案監控 + 手動啟動（過渡方案）

```bash
# 引擎建立觸發檔案
echo "task-001" > .dev-flow/automation/trigger-claude.flag

# 另一個終端監控並提示
./scripts/watch-triggers.sh

# 輸出：
# 🔔 請啟動 Claude Code 並執行：
#     cat .dev-flow/automation/claude-command.txt
#     # 然後按照指令執行

# 您手動啟動 Claude Code，複製貼上指令

# Claude Code 完成後，引擎自動檢測到狀態變更，繼續循環
```

#### 方案 4：Web Hooks（如果工具支援）

```bash
trigger_claude_code() {
    curl -X POST https://claude-code-webhook-url \
        -H "Content-Type: application/json" \
        -d '{
          "action": "execute_task",
          "task_id": "'$TASK_ID'",
          "context": "..."
        }'
}
```

---

## 進階功能

### 1. 並行執行（如果任務無依賴）

```bash
# 修改 find_next_ready_task 返回多個
find_all_ready_tasks() {
    grep -l "status: ready" .dev-flow/tasks/task-*.md 2>/dev/null | \
        xargs basename -s .md 2>/dev/null
}

# 啟動多個 Claude Code 實例
for task in $(find_all_ready_tasks); do
    trigger_claude_code "$task" &
done
wait
```

### 2. 失敗重試策略

已內建在 automation-engine.sh：
- 最多重試 3 次
- 每次失敗等待 1 分鐘
- 達到上限後暫停並通知人工

### 3. 中途暫停/恢復

```bash
# 暫停
echo "paused" > .dev-flow/automation/control.flag
# 引擎檢測到後會優雅停止

# 恢復
rm .dev-flow/automation/control.flag
./scripts/automation-engine.sh
# 從上次狀態繼續
```

### 4. 進度監控 Dashboard

```bash
# 即時監控腳本
./scripts/monitor-progress.sh

# 輸出：
┌─────────────────────────────────────┐
│   自動化工作流進度                   │
├─────────────────────────────────────┤
│ 總任務: 4                            │
│ 完成: 2 (50%)                        │
│ 進行中: task-003                     │
│ 當前 Actor: codex (審核中)           │
│                                     │
│ ████████████░░░░░░░░░░░░ 50%        │
│                                     │
│ 預計剩餘時間: 45 分鐘                 │
└─────────────────────────────────────┘
```

---

## 完整工作流時間線

```
T+0:00  您：在 ChatGPT 提出需求
T+0:05  ChatGPT：產生 spec.md
T+0:10  您：要求 Codex 拆分任務
T+0:15  Codex：建立 4 個任務 + 上下文包
T+0:20  您：啟動自動化引擎
        ./scripts/automation-engine.sh

[自動執行，無需介入]

T+0:25  Cycle 1: Claude Code 執行 task-001
T+0:35  Cycle 1: Codex 審核 task-001 → PASS
T+0:40  Cycle 2: Claude Code 執行 task-002
T+0:50  Cycle 2: Codex 審核 task-002 → PASS
T+0:55  Cycle 3: Claude Code 執行 task-003
T+1:05  Cycle 3: Codex 審核 task-003 → FAIL (退回)
T+1:10  Cycle 4: Claude Code 修改 task-003
T+1:20  Cycle 4: Codex 重新審核 → PASS
T+1:25  Cycle 5: Claude Code 執行 task-004
T+1:35  Cycle 5: Codex 審核 task-004 → PASS

T+1:40  通知您：所有任務完成！

[您介入]

T+1:45  您：檢閱報告
T+1:50  您：整合測試
T+2:00  您：Merge 到 main
T+2:05  ✅ 完成！
```

**您的總介入時間：約 25 分鐘**
**自動化執行時間：約 75 分鐘**

---

## 總結

### 您只需要介入 3 次

1. **開始**：提出需求 → 拆分任務 → 啟動引擎（15 分鐘）
2. **（中間全自動）** - 喝咖啡 ☕
3. **結束**：收到通知 → 檢閱 → Merge（10 分鐘）

### 系統自動處理

- ✅ 所有任務的執行（Claude Code）
- ✅ 所有任務的審核（Codex）
- ✅ 失敗重試
- ✅ 依賴解鎖
- ✅ Git commit & push
- ✅ 進度追蹤
- ✅ 完成通知

### 相比原需求的提升

| 項目 | 原需求 | 方案 C |
|------|-------|--------|
| 人工介入次數 | 每個任務 1 次 | 整個需求 2-3 次 |
| 開發時間 | 4 任務 × 30 分 = 120 分 | 25 分（人工）+ 自動 |
| Token 浪費 | 累積對話上下文 | 嚴格控制 < 5K/task |
| 可追蹤性 | 依賴人工記錄 | 完整日誌 + 報告 |

---

**這才是真正的自動化！** 🚀

需要我：
1. 實作完整的 automation-engine.sh？
2. 設計 MCP bridge？
3. 建立監控 dashboard？
