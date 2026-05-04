# 極簡 AI 開發工作流系統 - 完整架構設計

**版本：** 1.0  
**日期：** 2026-05-04  
**目的：** 建立一個 token 高效、易維護的多 Agent 協作開發系統

---

## 目錄

1. [系統概述](#系統概述)
2. [核心設計原則](#核心設計原則)
3. [完整檔案結構](#完整檔案結構)
4. [Agent 角色定義](#agent-角色定義)
5. [工作流程詳解](#工作流程詳解)
6. [上下文控制機制](#上下文控制機制)
7. [檔案格式規範](#檔案格式規範)
8. [自動化腳本規範](#自動化腳本規範)
9. [實施步驟](#實施步驟)

---

## 系統概述

### 目標

建立一個極簡的 AI 協作開發系統，實現：

1. **ChatGPT Web** - 需求分析 + 架構設計
2. **Codex** - 任務拆分 + 審核測試 + commit/push
3. **Claude Code** - 實際開發執行
4. **人工** - 最終審核 + merge

### 核心優勢

- ✅ **極簡設計** - 僅 12 個核心檔案
- ✅ **Token 高效** - 每次交互 < 5,000 tokens
- ✅ **零依賴** - 不需安裝額外工具
- ✅ **立即可用** - 5 分鐘即可開始使用
- ✅ **可追蹤** - 所有狀態都在 Git 中
- ✅ **人工可控** - 任何時候都可介入

---

## 核心設計原則

### 1. 及時取用，用完即棄

每個 Agent 只讀取當下任務需要的最小資訊集，不載入整個專案歷史。

### 2. 分層上下文

```
Layer 0: 永遠需要（< 500 tokens）     ← Agent 角色指示
Layer 1: 任務相關（< 2,000 tokens）   ← 當前任務 + 上下文包
Layer 2: 按需查詢（明確要求時才讀）   ← 完整 spec.md
```

### 3. 交接檔案機制

Agent 之間透過小型交接檔案通訊，避免累積歷史對話。

### 4. 上下文包預製

建立任務時就準備好「這個任務會需要什麼」，執行時直接讀取。

---

## 完整檔案結構

```
project-root/
├── .dev-flow/                           # 開發工作流核心目錄
│   ├── context/                         # Agent 上下文（Layer 0）
│   │   ├── chatgpt-role.md             # ChatGPT 角色指示（< 500 tokens）
│   │   ├── codex-role.md               # Codex 角色指示（< 500 tokens）
│   │   └── claude-role.md              # Claude Code 角色指示（< 500 tokens）
│   │
│   ├── handoff/                         # Agent 交接區
│   │   ├── to-codex.md                 # Claude → Codex 交接檔
│   │   └── to-claude.md                # Codex → Claude 交接檔
│   │
│   ├── triggers/                        # 自動觸發機制（新增）
│   │   └── codex-review-needed.flag    # Claude 建立此檔案通知 Codex
│   │
│   ├── tasks/                           # 任務目錄
│   │   ├── task-001.md                 # 任務規格
│   │   ├── task-001.context.md         # 任務上下文包（< 2,000 tokens）
│   │   ├── task-002.md
│   │   ├── task-002.context.md
│   │   └── ...
│   │
│   ├── spec.md                          # 完整架構規格（Layer 2，不自動載入）
│   │
│   └── status.json                      # 系統狀態追蹤（可選）
│
├── .claude/                             # Claude Code 設定
│   └── commands/
│       ├── check-task.md               # 檢查並開始任務
│       ├── finish-task.md              # 完成任務並通知 Codex（新增）
│       └── read-spec.md                # 讀取 spec（需要時）
│
├── scripts/                             # 自動化腳本
│   ├── create-task-context.sh          # 建立任務上下文包
│   ├── check-context-size.sh           # 檢查上下文大小
│   ├── watch-for-codex.sh              # 監控並觸發 Codex 審核（新增）
│   └── clean-handoff.sh                # 清理已處理的交接檔
│
├── src/                                 # 實際專案程式碼
│   └── ...
│
└── README.md                            # 專案說明
```

---

## Agent 角色定義

### 1. ChatGPT Web - 需求分析師

**職責：**
- 接收人工需求
- 分析並設計系統架構
- 產出 spec.md
- 提供技術建議

**輸入：**
- 人工需求描述
- 已有的系統狀態（如果需要）

**輸出：**
- `.dev-flow/spec.md` - 完整架構規格
- 建議的技術棧
- 資料庫 schema
- API 設計
- 檔案結構建議

**Token 限制：**
- 單次對話不超過 10,000 tokens
- spec.md 建議 < 5,000 tokens（Codex 可能需要完整讀取）

---

### 2. Codex - 任務管理者 + 審核者 + 提交者

**三重身份：**

**身份 A：任務管理者**
- 讀取 spec.md 並拆分成小任務
- 為每個任務建立上下文包
- 管理任務依賴關係

**身份 B：審核者**
- 自動接收 Claude Code 的完成通知
- 審核程式碼品質和規格符合度
- 執行測試驗證
- 判斷 PASS/FAIL

**身份 C：提交者**
- 審核通過 → commit 和 push 到 task branch
- 審核失敗 → 退回修改給 Claude Code

**工作模式：**
- **模式 A：任務拆分**
  - 讀取完整 spec.md
  - 建立多個 task-XXX.md
  - 為每個任務建立 context.md
  
- **模式 B：審核**
  - 讀取交接檔案
  - 讀取當前任務
  - 檢查程式碼變更
  - 執行測試
  - 寫入審核結果

**Token 限制：**
- 模式 A：可讀取完整 spec.md（< 10,000 tokens）
- 模式 B：< 5,000 tokens

---

### 3. Claude Code - 執行者 + 通知者

**職責：**
1. 檢查待執行的任務
2. 讀取任務規格和上下文包
3. 執行開發工作
4. **自動通知 Codex 審核**（關鍵機制）

**完成任務後的自動流程：**
1. 填寫執行結果
2. 將 status 改為 `review`
3. 建立交接檔案 `to-codex.md`
4. **觸發 Codex 審核**（透過檔案監控或明確指令）

**工作原則：**
- 一次只執行一個任務
- 嚴格遵守任務規格
- 不修改任務範圍外的檔案
- 不「順便」加功能
- **完成後必須通知 Codex**

**Token 限制：**
- < 3,000 tokens per task

---

## 工作流程詳解

### 階段 1：需求分析與架構設計

**執行者：** ChatGPT Web  
**觸發：** 人工提出需求

#### 輸入格式（人工 → ChatGPT）

```markdown
【專案背景】
Discord Bot - 社群管理機器人

【新功能需求】
實作自動歡迎新成員功能：
1. 成員加入時發送歡迎訊息
2. 訊息內容可自定義
3. 記錄加入時間到資料庫

【已有基礎】
- 資料庫連線已建立（PostgreSQL）
- Bot 基礎架構已完成（Discord.js v14）

【技術限制】
- 必須使用 TypeScript
- 環境變數管理用 dotenv
- 不使用 ORM（直接用 pg）

【產出要求】
1. 只產出這個功能的架構設計
2. 定義需要建立的檔案
3. 資料庫 schema 變更（如果有）
4. 控制在 3,000 tokens 以內
```

#### 輸出格式（ChatGPT → spec.md）

```markdown
# 自動歡迎新成員功能 - 架構設計

## 功能概述
當新成員加入 Discord 伺服器時，自動發送歡迎訊息並記錄到資料庫。

## 技術架構

### 檔案結構
```
src/
├── events/
│   └── guildMemberAdd.ts       # 新成員加入事件處理器
├── handlers/
│   └── welcomeHandler.ts       # 歡迎訊息處理邏輯
└── database/
    └── queries/
        └── memberQueries.ts    # 成員資料庫操作
```

### 資料庫 Schema
```sql
-- 新增資料表
CREATE TABLE member_joins (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    guild_id VARCHAR(255) NOT NULL,
    joined_at TIMESTAMP DEFAULT NOW()
);

-- 新增索引
CREATE INDEX idx_member_joins_user_id ON member_joins(user_id);
```

### 環境變數
```
WELCOME_CHANNEL_ID=123456789  # 發送歡迎訊息的頻道 ID
WELCOME_MESSAGE=歡迎 {username} 加入伺服器！  # 訊息模板
```

## 模組規格

### 1. guildMemberAdd.ts
**職責：** 註冊 Discord 事件監聽器

**輸入：** Discord.js GuildMember 事件
**輸出：** 觸發 welcomeHandler

**程式邏輯：**
```typescript
import { Client, GuildMember } from 'discord.js';
import { handleWelcome } from '../handlers/welcomeHandler';

export function registerGuildMemberAddEvent(client: Client) {
    client.on('guildMemberAdd', async (member: GuildMember) => {
        await handleWelcome(member);
    });
}
```

### 2. welcomeHandler.ts
**職責：** 處理歡迎邏輯

**輸入：** GuildMember 物件
**輸出：** 發送訊息 + 寫入資料庫

**必須包含：**
- 環境變數讀取
- 訊息模板替換（{username}）
- 錯誤處理
- 資料庫寫入呼叫

**錯誤處理：**
- 如果頻道不存在：記錄錯誤但不中斷
- 如果資料庫寫入失敗：記錄錯誤但訊息仍發送

### 3. memberQueries.ts
**職責：** 資料庫操作

**提供函數：**
```typescript
async function logMemberJoin(
    userId: string,
    username: string,
    guildId: string
): Promise<void>
```

**使用現有的：** database/connection.ts 的 pool 物件

## 依賴關係
- 依賴已完成的資料庫連線模組
- 依賴 Bot client 初始化（在 bot.ts）

## 測試建議
1. 手動測試：邀請測試帳號加入伺服器
2. 檢查：訊息是否正確發送
3. 檢查：資料庫是否正確記錄

## 實作順序建議
1. task-001: 建立資料庫 schema
2. task-002: 實作 memberQueries.ts
3. task-003: 實作 welcomeHandler.ts
4. task-004: 實作 guildMemberAdd.ts 並註冊事件

---
總計約 2,800 tokens
```

---

### 階段 2：任務拆分

**執行者：** Codex  
**觸發：** 人工指示「拆分任務」

#### 人工給 Codex 的指令

```
讀取 .dev-flow/spec.md，按照 .dev-flow/context/codex-role.md 的指示
將架構拆分成多個任務。

每個任務：
- 獨立可完成
- < 300 行程式碼
- 包含明確的完成標準
- 建立對應的上下文包
```

#### Codex 執行步驟

```bash
# 1. 讀取角色指示
cat .dev-flow/context/codex-role.md

# 2. 讀取完整 spec
cat .dev-flow/spec.md

# 3. 拆分任務（建立 4 個任務檔案）
# task-001: 資料庫 schema
# task-002: 資料庫查詢函數
# task-003: 歡迎訊息處理邏輯
# task-004: 事件註冊

# 4. 為每個任務建立上下文包
./scripts/create-task-context.sh task-001
./scripts/create-task-context.sh task-002
./scripts/create-task-context.sh task-003
./scripts/create-task-context.sh task-004
```

#### 任務檔案範例

**`.dev-flow/tasks/task-001.md`**

```markdown
---
task_id: task-001
status: ready
assigned_to: claude_code
created: 2026-05-04
depends_on: []
estimated_lines: 20
---

# 任務：建立成員加入記錄資料表

## 上下文
- **依賴：** 無（使用現有資料庫連線）
- **專案階段：** 歡迎新成員功能 - 資料層
- **相關規格：** spec.md「資料庫 Schema」章節

## 要做什麼

建立資料庫 migration 檔案和執行腳本：

1. 建立 `src/database/migrations/003_create_member_joins.sql`
2. 定義 `member_joins` 資料表
3. 建立必要的索引
4. （可選）建立 migration 執行腳本

## 規格細節

**資料表結構：**
```sql
CREATE TABLE member_joins (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    guild_id VARCHAR(255) NOT NULL,
    joined_at TIMESTAMP DEFAULT NOW()
);
```

**索引：**
```sql
CREATE INDEX idx_member_joins_user_id ON member_joins(user_id);
```

**注意事項：**
- user_id 是 Discord 的用戶 ID（字串）
- guild_id 是 Discord 的伺服器 ID（字串）
- joined_at 使用 server 時間自動填入

## 檔案位置

- Migration 檔案：`src/database/migrations/003_create_member_joins.sql`
- （如已有 migration runner）遵循現有命名規則

## 完成標準

- [ ] SQL 檔案已建立
- [ ] 語法正確（可被 PostgreSQL 執行）
- [ ] 包含資料表和索引
- [ ] 檔案放在正確位置

## 執行結果（由 Claude Code 填寫）

**完成時間：**  
**修改的檔案：**
-  

**備註：**

## 審核結果（由 Codex 填寫）

**審核時間：**  
**審核結果：** PASS / FAIL  
**測試輸出：**
```

```

**commit hash：** [如果 PASS]
```

**`.dev-flow/tasks/task-001.context.md`**

```markdown
# Task-001 上下文包

## 從 spec.md 提取的相關內容

### 資料庫 Schema
```sql
CREATE TABLE member_joins (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    guild_id VARCHAR(255) NOT NULL,
    joined_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_member_joins_user_id ON member_joins(user_id);
```

## 專案現有結構

```
src/database/
├── connection.ts          # 資料庫連線 pool
├── migrations/
│   ├── 001_initial.sql   # 已存在
│   └── 002_xxx.sql       # 已存在
```

## 依賴的前置任務

無 - 這是第一個任務

## 相關技術資訊

- **資料庫：** PostgreSQL 14+
- **Migration 慣例：** 檔名格式 `NNN_description.sql`
- **執行方式：** （稍後由 task-002 或人工執行）

## 注意事項

- 這個任務只建立 SQL 檔案
- 不需要實際執行 migration（會由部署流程處理）
- 確保與現有 migration 檔案命名一致

---
總計約 800 tokens
```

---

### 階段 3：Claude Code 執行任務並自動通知 Codex

**執行者：** Claude Code  
**觸發：** 人工執行 `/check-task` 或自動檢查

#### Claude Code 工作流程

```bash
# 1. 讀取角色指示（< 500 tokens）
cat .dev-flow/context/claude-role.md

# 2. 檢查是否有給我的訊息
if [ -f .dev-flow/handoff/to-claude.md ]; then
    cat .dev-flow/handoff/to-claude.md
    # 如果是退回修改，優先處理
fi

# 3. 找下一個 ready 任務（如果沒有退回的）
NEXT_TASK=$(grep -l "status: ready" .dev-flow/tasks/*.md | sort | head -1)

# 4. 讀取任務和上下文包（< 2,500 tokens）
cat "$NEXT_TASK"
cat "${NEXT_TASK%.md}.context.md"

# 總上下文：< 3,500 tokens

# 5. 執行任務...
```

#### 完成任務後的自動通知流程

**Claude Code 完成開發後，執行 `/finish-task` 指令：**

**步驟 1：更新任務狀態**
```bash
# 將 task-XXX.md 的 status 從 in_progress 改為 review
sed -i 's/status: in_progress/status: review/' .dev-flow/tasks/task-001.md
```

**步驟 2：填寫執行結果**
（在 task-001.md 的「執行結果」區塊填寫）

**步驟 3：建立交接檔案**

**Claude Code 建立：** `.dev-flow/handoff/to-codex.md`

```markdown
---
from: claude_code
to: codex
task_id: task-001
timestamp: 2026-05-04T14:30:00Z
---

# 任務完成通知

## 任務 ID
task-001

## 完成摘要
建立了成員加入記錄的資料庫 migration 檔案。

## 修改的檔案
- src/database/migrations/003_create_member_joins.sql (新建)

## 實作細節
- 定義了 member_joins 資料表（4 個欄位）
- 建立了 user_id 的索引以加速查詢
- 遵循專案現有的 migration 命名規則（003_xxx.sql）

## 注意事項
- 這個 SQL 檔案尚未執行，需要部署時或手動執行
- 測試建議：可以在開發環境用 psql < 003_create_member_joins.sql 驗證語法

## 請審核
檢查項目：
1. SQL 語法正確性
2. 資料型別是否符合規格
3. 索引是否正確建立

---
總計約 400 tokens
```

**步驟 4：建立觸發旗標（自動通知機制）**

```bash
# 建立旗標檔案，通知 Codex 有任務需要審核
echo "task-001" > .dev-flow/triggers/codex-review-needed.flag
```

**步驟 5：（可選）自動觸發 Codex**

有三種方式觸發 Codex 審核：

**方式 A：手動觸發（最簡單）**
```
Claude Code 完成後，您對 Codex 說：
"檢查 .dev-flow/handoff/to-codex.md 並進行審核"
```

**方式 B：監控腳本觸發（推薦）**
```bash
# 在背景執行監控腳本
./scripts/watch-for-codex.sh &

# 這個腳本會：
# 1. 每 30 秒檢查 .dev-flow/triggers/codex-review-needed.flag
# 2. 如果存在，輸出提示訊息
# 3. 您看到提示後，啟動 Codex 審核
```

**方式 C：完全自動化（進階）**
```bash
# 使用 git hooks 或 CI/CD
# 當 to-codex.md 被建立時，自動觸發 Codex
# （需要額外設定）
```

#### 監控腳本範例

**`scripts/watch-for-codex.sh`**

```bash
#!/bin/bash
# 監控 Codex 審核觸發旗標

echo "🔍 開始監控 Codex 審核需求..."

while true; do
    if [ -f .dev-flow/triggers/codex-review-needed.flag ]; then
        TASK_ID=$(cat .dev-flow/triggers/codex-review-needed.flag)
        
        echo ""
        echo "========================================="
        echo "🔔 Codex 審核通知"
        echo "========================================="
        echo "任務 ID: $TASK_ID"
        echo "交接檔案: .dev-flow/handoff/to-codex.md"
        echo ""
        echo "請啟動 Codex 並執行："
        echo "  '審核 .dev-flow/handoff/to-codex.md 指定的任務'"
        echo "========================================="
        echo ""
        
        # 發出系統通知（如果支援）
        if command -v notify-send &> /dev/null; then
            notify-send "Codex 審核需求" "任務 $TASK_ID 已完成，需要審核"
        fi
        
        # 刪除旗標（避免重複通知）
        rm .dev-flow/triggers/codex-review-needed.flag
        
        # 等待 10 秒再繼續監控
        sleep 10
    fi
    
    sleep 30
done
```

---

### 階段 4：Codex 審核

**執行者：** Codex  
**觸發：** 人工指示「審核任務」

#### Codex 審核流程

```bash
# 1. 讀取角色指示（< 500 tokens）
cat .dev-flow/context/codex-role.md

# 2. 讀取交接檔案（< 500 tokens）
cat .dev-flow/handoff/to-codex.md
# 得知：task-001 需要審核

# 3. 讀取任務和上下文（< 2,500 tokens）
cat .dev-flow/tasks/task-001.md
cat .dev-flow/tasks/task-001.context.md

# 總上下文：< 3,500 tokens

# 4. 檢查程式碼變更
git diff --name-only
git diff src/database/migrations/003_create_member_joins.sql

# 5. 執行測試（如果適用）
# 對於 SQL：語法檢查
psql -U postgres -d testdb --dry-run -f src/database/migrations/003_create_member_joins.sql

# 6. 判斷結果
```

#### 審核通過 → Commit & Push

```bash
# 更新任務檔案的審核結果
# （在 task-001.md 的審核區塊填寫）

# Commit
git add src/database/migrations/003_create_member_joins.sql
git add .dev-flow/tasks/task-001.md
git commit -m "feat(db): add member_joins table migration

Task ID: task-001
Status: PASS
Files:
- src/database/migrations/003_create_member_joins.sql

Reviewed and tested - SQL syntax valid."

# Push to task branch
git push origin task/001

# 清理交接檔案
rm .dev-flow/handoff/to-codex.md

# 更新任務狀態
# （將 task-001.md 的 status 改為 done）
```

**更新 task-001.md：**

```markdown
## 審核結果（由 Codex 填寫）

**審核時間：** 2026-05-04 14:45  
**審核結果：** PASS  
**測試輸出：**
```
$ psql --dry-run < 003_create_member_joins.sql
Syntax OK
```

**commit hash：** a3f8c92
**branch：** task/001
```

---

#### 審核失敗 → 退回修改

如果發現問題，Codex 建立：`.dev-flow/handoff/to-claude.md`

```markdown
---
from: codex
to: claude_code
task_id: task-001
timestamp: 2026-05-04T14:50:00Z
action: revise
---

# 審核結果：需要修改

## 任務 ID
task-001

## 問題清單

### 問題 1：資料型別不當
**檔案：** src/database/migrations/003_create_member_joins.sql  
**位置：** user_id 欄位定義  
**問題：** VARCHAR(255) 對於 Discord ID 太短，Discord ID 是 18-19 位數字

**建議修改：**
```sql
user_id VARCHAR(20) NOT NULL,  -- Discord ID 長度
```

### 問題 2：缺少索引
**位置：** 檔案末端  
**問題：** 規格要求建立 guild_id 索引（用於查詢特定伺服器的加入記錄），但檔案中沒有

**建議新增：**
```sql
CREATE INDEX idx_member_joins_guild_id ON member_joins(guild_id);
```

## 修改後請執行

1. 修改 SQL 檔案
2. 更新 task-001.md 的「執行結果」區塊
3. 再次通知審核

---
總計約 500 tokens
```

**同時更新：** task-001.md 的 status 改回 `in_progress`

Claude Code 下次啟動時會優先讀取這個檔案並修改。

---

### 階段 5：人工最終審核

**執行者：** 您  
**觸發：** Codex push 到 task branch 後

```bash
# 1. 檢查 task branch
git fetch
git checkout task/001

# 2. 審查變更
git diff main
cat src/database/migrations/003_create_member_joins.sql

# 3. 檢查任務完成狀態
cat .dev-flow/tasks/task-001.md

# 4. 如果滿意
git checkout main
git merge task/001
git push

# 5. 清理 task branch
git branch -d task/001
git push origin --delete task/001
```

---

## 上下文控制機制

### Token 預算分配

| Agent | 模式 | 預算 | 包含內容 |
|-------|------|------|---------|
| ChatGPT | 需求分析 | 10,000 | 需求 + 背景 + 產出 spec |
| Codex | 任務拆分 | 10,000 | spec.md + 拆分邏輯 |
| Codex | 審核 | 5,000 | 交接 + 任務 + 上下文包 + diff |
| Claude | 執行 | 3,000 | 角色 + 任務 + 上下文包 |

### 上下文包內容規範

**task-XXX.context.md 必須包含：**

1. **Spec 片段提取**（< 1,000 tokens）
   - 只包含這個任務直接相關的部分
   - 從 spec.md 複製內容，不是引用連結

2. **依賴資訊**（< 300 tokens）
   - 列出前置任務及其狀態
   - 說明這個任務會使用哪些已完成的模組

3. **檔案位置指引**（< 200 tokens）
   - 專案現有的檔案結構
   - 新檔案應該放哪裡

4. **注意事項**（< 500 tokens）
   - 程式碼風格要求
   - 已知的技術限制
   - 特殊處理需求

**總計：< 2,000 tokens**

### 禁止行為清單

**Claude Code 禁止：**
- ❌ 讀取 spec.md（除非任務明確要求）
- ❌ 讀取其他任務的 .md 檔案
- ❌ 讀取完整的 git log
- ❌ 「為了理解全貌」讀取任務外的檔案

**Codex 在審核模式時禁止：**
- ❌ 重新讀取完整 spec.md
- ❌ 讀取所有歷史任務
- ❌ 載入整個專案的程式碼庫

---

## 檔案格式規範

### 1. spec.md 格式

```markdown
# [功能名稱] - 架構設計

## 功能概述
[1-2 句話說明這個功能做什麼]

## 技術架構

### 檔案結構
```
[目錄樹]
```

### 資料庫 Schema（如果有）
```sql
[SQL DDL]
```

### 環境變數（如果有）
```
KEY=value
```

## 模組規格

### 1. [檔案名稱]
**職責：** [做什麼]
**輸入：** [接收什麼]
**輸出：** [產出什麼]

**必須包含：**
- [要點 1]
- [要點 2]

**錯誤處理：**
- [情境] → [處理方式]

### 2. [下一個檔案]
...

## 依賴關係
- [列出依賴的已有模組]

## 測試建議
1. [測試方式 1]
2. [測試方式 2]

## 實作順序建議
1. task-001: [描述]
2. task-002: [描述]
```

### 2. 任務檔案格式（task-XXX.md）

```markdown
---
task_id: task-XXX
status: ready | in_progress | review | done | blocked
assigned_to: claude_code
created: YYYY-MM-DD
depends_on: [task-YYY, task-ZZZ] 或 []
estimated_lines: N
---

# 任務：[簡短標題]

## 上下文
- **依賴：** [前置任務] 或 無
- **專案階段：** [這是哪個功能的哪個部分]
- **相關規格：** spec.md「[章節名稱]」

## 要做什麼

[條列式清單]

1. [步驟 1]
2. [步驟 2]

## 規格細節

[從 spec.md 複製的詳細規格]

## 檔案位置

- [檔案路徑說明]

## 完成標準

- [ ] [可驗證的標準 1]
- [ ] [可驗證的標準 2]

## 執行結果（由 Claude Code 填寫）

**完成時間：**  
**修改的檔案：**
-  

**備註：**

## 審核結果（由 Codex 填寫）

**審核時間：**  
**審核結果：** PASS / FAIL  
**測試輸出：**
```

```

**問題：** [如果 FAIL]  
**commit hash：** [如果 PASS]
```

### 3. 交接檔案格式

**to-codex.md（Claude → Codex）**

```markdown
---
from: claude_code
to: codex
task_id: task-XXX
timestamp: YYYY-MM-DDTHH:MM:SSZ
---

# 任務完成通知

## 任務 ID
task-XXX

## 完成摘要
[3-5 句話說明做了什麼]

## 修改的檔案
- [檔案路徑] (新建/修改/刪除)

## 實作細節
[關鍵決策或特殊處理]

## 注意事項
[審核時需要特別注意的地方]

## 請審核
檢查項目：
1. [項目 1]
2. [項目 2]
```

**to-claude.md（Codex → Claude）**

```markdown
---
from: codex
to: claude_code
task_id: task-XXX
timestamp: YYYY-MM-DDTHH:MM:SSZ
action: revise | clarify
---

# 審核結果：需要修改

## 任務 ID
task-XXX

## 問題清單

### 問題 1：[問題標題]
**檔案：** [檔案路徑]  
**位置：** [具體位置]  
**問題：** [詳細說明]

**建議修改：**
```[language]
[修改後的程式碼]
```

### 問題 2：...

## 修改後請執行
[後續步驟]
```

---

## 自動化腳本規範

### 1. create-task-context.sh

**用途：** 從 spec.md 和任務檔案自動產生上下文包

**使用：**
```bash
./scripts/create-task-context.sh task-001
```

**功能：**
1. 讀取 task-001.md
2. 提取「相關規格」章節名稱
3. 從 spec.md 擷取該章節
4. 列出依賴的任務
5. 產出 task-001.context.md

**實作要點：**
```bash
#!/bin/bash
TASK_ID=$1
TASK_FILE=".dev-flow/tasks/${TASK_ID}.md"
CONTEXT_FILE=".dev-flow/tasks/${TASK_ID}.context.md"

# 提取相關章節
SPEC_SECTION=$(grep "相關規格：" "$TASK_FILE" | sed 's/.*「//g' | sed 's/」.*//g')

# 從 spec.md 擷取
sed -n "/## $SPEC_SECTION/,/^## /p" .dev-flow/spec.md | head -n -1 > temp.md

# 建立上下文包
cat > "$CONTEXT_FILE" << EOF
# $TASK_ID 上下文包

## 從 spec.md 提取的相關內容
$(cat temp.md)

## 依賴的前置任務
$(grep "depends_on:" "$TASK_FILE" | sed 's/depends_on: //g')

## 注意事項
- 遵循專案程式碼風格
- 錯誤要適當處理
EOF

rm temp.md
```

### 2. watch-for-codex.sh（新增 - 自動通知機制）

**用途：** 監控 Claude Code 完成任務，自動提醒啟動 Codex 審核

**使用：**
```bash
# 在背景執行
./scripts/watch-for-codex.sh &

# 或在獨立終端視窗執行
./scripts/watch-for-codex.sh
```

**功能：**
1. 每 30 秒檢查 `.dev-flow/triggers/codex-review-needed.flag`
2. 如果檔案存在：
   - 顯示通知訊息
   - 顯示任務 ID
   - 提示如何啟動 Codex
   - 發送系統通知（如果支援）
3. 刪除旗標檔案（避免重複通知）

**完整實作：**
```bash
#!/bin/bash
# 監控 Codex 審核觸發旗標

echo "🔍 開始監控 Codex 審核需求..."
echo "按 Ctrl+C 停止監控"
echo ""

while true; do
    if [ -f .dev-flow/triggers/codex-review-needed.flag ]; then
        TASK_ID=$(cat .dev-flow/triggers/codex-review-needed.flag)
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo ""
        echo "========================================="
        echo "🔔 Codex 審核通知"
        echo "========================================="
        echo "時間: $TIMESTAMP"
        echo "任務 ID: $TASK_ID"
        echo "交接檔案: .dev-flow/handoff/to-codex.md"
        echo ""
        echo "📋 Codex 啟動指令："
        echo "  審核 .dev-flow/handoff/to-codex.md 指定的任務"
        echo ""
        echo "或手動執行："
        echo "  cat .dev-flow/handoff/to-codex.md"
        echo "  # 讀取任務詳情後執行審核"
        echo "========================================="
        echo ""
        
        # 發出系統通知（macOS）
        if command -v osascript &> /dev/null; then
            osascript -e "display notification \"任務 $TASK_ID 需要審核\" with title \"Codex 審核通知\""
        fi
        
        # 發出系統通知（Linux）
        if command -v notify-send &> /dev/null; then
            notify-send "Codex 審核通知" "任務 $TASK_ID 已完成，需要審核"
        fi
        
        # 刪除旗標（避免重複通知）
        rm .dev-flow/triggers/codex-review-needed.flag
        
        # 記錄到日誌（可選）
        echo "$TIMESTAMP - Task $TASK_ID ready for review" >> .dev-flow/review-notifications.log
        
        # 等待 10 秒再繼續監控（避免立即重複）
        sleep 10
    fi
    
    # 每 30 秒檢查一次
    sleep 30
done
```

**進階：與 Codex 整合**

如果您想要 Codex 自動啟動審核（而不只是通知），可以修改腳本：

```bash
# 在腳本中加入 Codex 自動啟動邏輯
if [ -f .dev-flow/triggers/codex-review-needed.flag ]; then
    TASK_ID=$(cat .dev-flow/triggers/codex-review-needed.flag)
    
    echo "自動啟動 Codex 審核..."
    
    # 方式 1: 如果 Codex 支援 CLI
    # codex --review .dev-flow/handoff/to-codex.md
    
    # 方式 2: 建立審核指令檔
    cat > .dev-flow/triggers/codex-command.txt << EOF
讀取 .dev-flow/context/codex-role.md
讀取 .dev-flow/handoff/to-codex.md
按照審核流程執行
EOF
    
    echo "Codex 指令已準備: .dev-flow/triggers/codex-command.txt"
    echo "請在 Codex 中執行該檔案的內容"
fi
```

### 3. check-context-size.sh

**用途：** 檢查所有上下文檔案是否超出 token 限制

**使用：**
```bash
./scripts/check-context-size.sh
```

**輸出範例：**
```
📊 上下文大小檢查
==================
✅ .dev-flow/context/claude-role.md: ~450 tokens
✅ .dev-flow/context/codex-role.md: ~480 tokens
⚠️  .dev-flow/tasks/task-003.context.md: ~2,100 tokens (建議 < 2000)
```

### 4. clean-handoff.sh

**用途：** 清理已處理的交接檔案

**使用：**
```bash
./scripts/clean-handoff.sh
```

**功能：**
- 檢查 handoff/ 中的檔案
- 如果對應的任務已經是 done 狀態，刪除交接檔
- 避免累積過期的交接訊息

---

## 實施步驟

### Phase 1：建立基礎結構（5 分鐘）

```bash
# 1. 建立目錄
mkdir -p .dev-flow/context
mkdir -p .dev-flow/handoff
mkdir -p .dev-flow/tasks
mkdir -p .claude/commands
mkdir -p scripts

# 2. 建立角色指示檔案
# （從下面的模板複製）

# 3. 建立 Claude Code 指令
# （從下面的模板複製）

# 4. 建立腳本
# （從上面的規範實作）

# 5. Git 初始化（如果還沒有）
git init
git add .dev-flow .claude scripts
git commit -m "chore: initialize minimal AI workflow system"
```

### Phase 2：第一次使用（10 分鐘）

**步驟 1：** 在 ChatGPT Web 產生 spec.md

提供您的需求 → ChatGPT 產出 spec.md → 複製到 `.dev-flow/spec.md`

**步驟 2：** Codex 拆分任務

```
讀取 .dev-flow/spec.md，按照 .dev-flow/context/codex-role.md 的指示
拆分成多個任務，並為每個任務建立上下文包。
```

**步驟 3：** Claude Code 執行第一個任務

在 Claude Code 執行：
```
/check-task
```

**步驟 4：** Codex 審核

等 Claude Code 完成後：
```
審核 .dev-flow/handoff/to-codex.md 指示的任務
```

**步驟 5：** 您 merge

```bash
git checkout task/001
git diff main
# 確認無誤
git checkout main
git merge task/001
```

### Phase 3：持續使用

重複 Phase 2 的步驟 3-5，直到所有任務完成。

---

## 核心檔案模板

### .dev-flow/context/claude-role.md

```markdown
# Claude Code 角色指示

**版本：** 1.0  
**Token 預算：** < 500 tokens

## 你是誰
你是專案的執行者，負責按照任務規格完成開發工作。
**完成後必須自動通知 Codex 進行審核。**

## 讀取順序

每次開始工作時，按順序讀取：

1. **檢查交接檔案**（如果存在）
   ```bash
   cat .dev-flow/handoff/to-claude.md
   ```
   - 如果存在：這是 Codex 退回的修改，優先處理
   - 如果不存在：繼續下一步

2. **找下一個任務**
   ```bash
   grep -l "status: ready" .dev-flow/tasks/*.md | sort | head -1
   ```
   - 選擇編號最小的 ready 任務

3. **讀取任務和上下文**
   ```bash
   cat .dev-flow/tasks/task-XXX.md
   cat .dev-flow/tasks/task-XXX.context.md
   ```

## 工作原則

- ✅ 嚴格遵守任務規格
- ✅ 一次只做一個任務
- ✅ 簡單 > 聰明
- ❌ 不修改任務範圍外的檔案
- ❌ 不「順便」加功能
- ❌ 不重構任務外的程式碼

## 完成後（重要！）

### 步驟 1：填寫執行結果
- 更新 task-XXX.md 的「執行結果」區塊
- 列出所有修改的檔案
- 說明任何特殊決策

### 步驟 2：改變狀態
- status: in_progress → review

### 步驟 3：建立交接檔案
寫入 `.dev-flow/handoff/to-codex.md`：
- 任務 ID
- 完成摘要（< 300 字）
- 修改的檔案列表
- 審核重點提示

### 步驟 4：通知 Codex（自動觸發機制）
建立旗標檔案：
```bash
echo "task-XXX" > .dev-flow/triggers/codex-review-needed.flag
```

**重要：** 這個旗標會觸發 Codex 自動審核流程。
如果監控腳本正在執行，Codex 會立即收到通知。

## 禁止行為

❌ 不要讀取 spec.md（上下文包已包含需要的部分）  
❌ 不要讀取其他任務檔案  
❌ 不要讀取完整 git 歷史  
❌ 不要「為了理解」而讀取無關檔案  
❌ **不要忘記通知 Codex（步驟 4 是必須的！）**

## Token 預算

總上下文應 < 3,000 tokens：
- 角色指示：< 500
- 任務檔案：< 500
- 上下文包：< 2,000

---
總計約 520 tokens
```

### .dev-flow/context/codex-role.md

```markdown
# Codex 角色指示

**版本：** 1.0  
**三重身份：任務管理者 + 審核者 + 提交者**

---

## 身份 A：任務管理者

### 何時使用
人工要求「拆分任務」時啟動此模式

### Token 預算
< 10,000 tokens（可讀取完整 spec.md）

### 工作流程

**輸入：**
- .dev-flow/spec.md（完整規格）

**輸出：**
- 多個 task-XXX.md 檔案
- 對應的 task-XXX.context.md 檔案

**拆分原則：**
1. 每個任務 < 300 行程式碼
2. 獨立可測試
3. 明確的完成標準
4. 按依賴順序編號

**建立上下文包：**
```bash
./scripts/create-task-context.sh task-XXX
```

---

## 身份 B：審核者（主要身份）

### 何時啟動

**自動觸發：**
- 當 `.dev-flow/triggers/codex-review-needed.flag` 被建立時
- 監控腳本會發出通知
- 或人工定期檢查

**手動觸發：**
- 人工指示「審核任務」
- 人工指示「檢查待審核的任務」

### Token 預算
< 5,000 tokens

### 讀取順序

1. **交接檔案**（< 500 tokens）
   ```bash
   cat .dev-flow/handoff/to-codex.md
   ```
   - 這是 Claude Code 的完成報告
   - 包含任務 ID、修改的檔案、審核重點

2. **任務檔案**（< 2,500 tokens）
   ```bash
   TASK_ID=$(grep "task_id:" .dev-flow/handoff/to-codex.md | cut -d: -f2 | xargs)
   cat .dev-flow/tasks/$TASK_ID.md
   cat .dev-flow/tasks/$TASK_ID.context.md
   ```

3. **程式碼變更**（只看 diff，不讀全部）
   ```bash
   git diff --name-only
   git diff [具體檔案]
   ```

### 審核檢查清單

- [ ] 程式碼符合任務規格
- [ ] 沒有明顯的 bug
- [ ] 有基本的錯誤處理
- [ ] 檔案放在正確位置
- [ ] 程式碼風格一致
- [ ] （如適用）可以執行/測試

### 審核結果處理

#### 情況 A：審核通過 → Commit & Push

```bash
# 1. 填寫任務檔案的審核結果
#    在 task-XXX.md 的「審核結果」區塊填寫：
#    - 審核時間
#    - 審核結果: PASS
#    - 測試輸出
#    - commit hash（稍後填入）

# 2. Commit
git add [所有修改的檔案]
git add .dev-flow/tasks/$TASK_ID.md
git commit -m "feat: [簡短描述]

Task ID: $TASK_ID
Status: PASS
Files:
- [列出修改的檔案]

Reviewed and tested."

# 3. Push to task branch
git push origin task/${TASK_ID#task-}

# 4. 更新 commit hash 到任務檔案
COMMIT_HASH=$(git rev-parse HEAD)
# 填入 task-XXX.md 的審核結果區塊

# 5. 更新任務狀態為 done
sed -i 's/status: review/status: done/' .dev-flow/tasks/$TASK_ID.md

# 6. 清理交接檔案和旗標
rm .dev-flow/handoff/to-codex.md
rm -f .dev-flow/triggers/codex-review-needed.flag

echo "✅ 審核完成並已推送到 task/${TASK_ID#task-} 分支"
echo "請人工審核後 merge 到 main"
```

#### 情況 B：審核失敗 → 退回修改

```bash
# 1. 建立退回交接檔案
cat > .dev-flow/handoff/to-claude.md << 'EOF'
---
from: codex
to: claude_code
task_id: $TASK_ID
timestamp: $(date -Iseconds)
action: revise
---

# 審核結果：需要修改

## 任務 ID
$TASK_ID

## 問題清單

### 問題 1：[問題標題]
**檔案：** [檔案路徑]
**位置：** [具體位置]
**問題：** [詳細說明]

**建議修改：**
```[language]
[修改後的程式碼]
```

## 修改後請重新提交
更新檔案後，再次執行 /finish-task
EOF

# 2. 填寫任務檔案的審核結果
#    在 task-XXX.md 的「審核結果」區塊填寫：
#    - 審核時間
#    - 審核結果: FAIL
#    - 問題清單

# 3. 更新任務狀態為 in_progress
sed -i 's/status: review/status: in_progress/' .dev-flow/tasks/$TASK_ID.md

# 4. 清理 to-codex.md 和旗標
rm .dev-flow/handoff/to-codex.md
rm -f .dev-flow/triggers/codex-review-needed.flag

echo "⚠️  審核未通過，已退回給 Claude Code 修改"
echo "Claude Code 下次啟動時會優先處理這個退回"
```

---

## 身份 C：提交者

這個身份在「審核通過」時自動啟動（見上面的情況 A）。

主要職責：
- 執行 git commit
- 推送到 task branch
- 清理工作檔案
- 通知人工進行最終審核

---

## 禁止行為（審核模式）

❌ 不要重新讀取完整 spec.md  
❌ 不要讀取所有歷史任務  
❌ 不要載入整個專案程式碼庫  
❌ 不要「為了理解背景」而讀取無關檔案  
❌ 不要修改 Claude Code 的程式碼（只能退回要求修改）

---

## 快速啟動指令範例

**當收到審核通知時，執行：**

```
讀取 .dev-flow/context/codex-role.md 的「身份 B：審核者」部分
讀取 .dev-flow/handoff/to-codex.md
按照審核流程執行
```

---
總計約 780 tokens
```

### .claude/commands/check-task.md

```markdown
# Check Task

檢查並開始下一個任務。

## 執行步驟

1. **讀取角色指示**
   ```bash
   cat .dev-flow/context/claude-role.md
   ```

2. **檢查是否有退回的修改**
   ```bash
   if [ -f .dev-flow/handoff/to-claude.md ]; then
       echo "⚠️  有退回的修改需要處理"
       cat .dev-flow/handoff/to-claude.md
       exit 0
   fi
   ```

3. **找下一個 ready 任務**
   ```bash
   NEXT=$(grep -l "status: ready" .dev-flow/tasks/*.md | sort | head -1)
   
   if [ -z "$NEXT" ]; then
       echo "✅ 沒有待執行的任務"
       exit 0
   fi
   
   echo "📋 下一個任務："
   head -20 "$NEXT"
   ```

4. **詢問確認**
   > 我要開始執行這個任務嗎？

5. **等待回覆「開始」**

6. **讀取任務和上下文包**
   ```bash
   cat "$NEXT"
   cat "${NEXT%.md}.context.md"
   ```

7. **執行任務...**

8. **完成後執行 /finish-task**
```

### .claude/commands/finish-task.md（新增）

```markdown
# Finish Task

完成當前任務並自動通知 Codex 進行審核。

**重要：這個指令會自動觸發 Codex 審核流程！**

## 執行步驟

### 步驟 1：確認任務 ID

```bash
# 找出 status 為 in_progress 的任務
CURRENT_TASK=$(grep -l "status: in_progress" .dev-flow/tasks/*.md)

if [ -z "$CURRENT_TASK" ]; then
    echo "❌ 沒有進行中的任務"
    exit 1
fi

TASK_ID=$(basename "$CURRENT_TASK" .md)
echo "📋 完成任務: $TASK_ID"
```

### 步驟 2：填寫執行結果

提示我填寫以下資訊：
- 完成時間（自動填入當前時間）
- 修改的檔案列表
- 備註說明

然後更新 `$CURRENT_TASK` 檔案的「執行結果」區塊。

### 步驟 3：更新任務狀態

```bash
# 將 status 改為 review
sed -i 's/status: in_progress/status: review/' "$CURRENT_TASK"
```

### 步驟 4：建立交接檔案

建立 `.dev-flow/handoff/to-codex.md`：

```markdown
---
from: claude_code
to: codex
task_id: $TASK_ID
timestamp: $(date -Iseconds)
---

# 任務完成通知

## 任務 ID
$TASK_ID

## 完成摘要
[我填寫的摘要]

## 修改的檔案
[我填寫的檔案列表]

## 實作細節
[我填寫的關鍵決策]

## 注意事項
[我填寫的審核重點]

## 請審核
檢查項目：
[我填寫的檢查項目]
```

### 步驟 5：觸發 Codex 審核通知（自動化！）

```bash
# 建立旗標檔案
mkdir -p .dev-flow/triggers
echo "$TASK_ID" > .dev-flow/triggers/codex-review-needed.flag

echo ""
echo "========================================="
echo "✅ 任務完成！"
echo "========================================="
echo "任務 ID: $TASK_ID"
echo "狀態: review (待審核)"
echo ""
echo "🔔 Codex 通知已觸發"
echo ""
echo "如果監控腳本正在執行，Codex 將自動收到通知。"
echo "否則請手動啟動 Codex 並執行："
echo "  '審核 .dev-flow/handoff/to-codex.md 指定的任務'"
echo "========================================="
```

### 步驟 6：清理（可選）

```bash
# 如果之前有 to-claude.md（退回修改的情況），現在可以刪除
if [ -f .dev-flow/handoff/to-claude.md ]; then
    rm .dev-flow/handoff/to-claude.md
    echo "🗑️  已清理 to-claude.md"
fi
```

## 使用範例

```
Claude Code> /finish-task

📋 完成任務: task-003

請填寫執行結果：

完成時間: 2026-05-04 15:30
修改的檔案:
- src/handlers/welcomeHandler.ts (新建)
- src/events/guildMemberAdd.ts (修改)

備註: 實作了歡迎訊息功能，使用環境變數配置訊息模板

[更新檔案中...]
[建立交接檔案...]
[觸發通知...]

========================================
✅ 任務完成！
========================================
任務 ID: task-003
狀態: review (待審核)

🔔 Codex 通知已觸發

如果監控腳本正在執行，Codex 將自動收到通知。
否則請手動啟動 Codex 並執行：
  '審核 .dev-flow/handoff/to-codex.md 指定的任務'
========================================
```
```

---

## 總結

這個系統的設計核心：

1. **極簡** - 只有必要的檔案和流程
2. **Token 高效** - 嚴格的上下文控制
3. **可追蹤** - 所有狀態都在 Git 中
4. **人工可控** - 任何時候都可介入

**立即開始：**
1. 複製這個檔案的內容建立專案結構
2. 在 ChatGPT Web 產生第一個 spec.md
3. 用 Codex 拆分任務
4. 用 Claude Code 執行第一個任務

**預期效果：**
- 第一個任務可在 30 分鐘內完成
- 每個任務的 token 消耗 < 5,000
- 整個專案的開發週期縮短 50%+

---

**End of Document**
