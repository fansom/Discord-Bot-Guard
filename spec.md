# PersonaLink / Discord-Bot-Guard 專案規格與進度盤點

## 1. 文件目的

本文件用來記錄 Discord-Bot-Guard（目前產品方向對齊 PersonaLink Discord LFG Bot）的實際開發狀態、短期工程目標、已知待做內容與暫緩項目。文件重點不是長期願景，而是讓目前 repo 能進入可穩定測試的 Alpha 2 / Beta 前置狀態。

目前短期目標是完成 P0 穩定性地基：讓單伺服器發車流程在 Bot 重啟、舊按鈕、訊息刪除、權限不足、資料恢復失敗等異常情境下仍能穩定回應，不崩潰、不無回應、不產生錯誤狀態。

## 2. 目前可確認進度

### 2.1 Repo 狀態

目前 repo 已有 `package.json`，專案名稱為 `personalink-bot`，描述為 `Discord 自動發車 Bot`，主入口設定為 `index.js`，技術方向使用 Node.js、Discord.js v14、Express、dotenv。

目前可確認的阻塞點：`package.json` 內容存在 JSON 語法錯誤，`scripts.start` 後缺少逗號，`devDependencies.dotenv` 後也缺少逗號。這會導致套件管理器無法正常解析 package.json，屬於啟動前必修問題。

目前未在 repo root 確認到 `index.js`。由於 `package.json.main` 指向 `index.js`，若該檔案尚未存在，`pnpm start` 或 `node index.js` 會直接失敗。

目前未確認到既有 `spec.md`，因此本次新增本文件作為專案規格與進度追蹤基準。

### 2.2 產品階段判定

目前專案不應被視為可對外測試的完整 Beta。依照現有狀態，較合理定位是：Alpha 2 前置修正期。

Alpha 1 的目標是單伺服器基礎發車：`/開車` 建立房間、玩家加入、玩家退出、人數顯示、司機關閉房間、基礎房間公告。若實作尚未落地，應先補齊 Alpha 1；若已在其他檔案或分支完成，則目前主線仍需要把程式碼整理到 repo 並修正啟動問題。

Alpha 2 的目標不是擴功能，而是補穩定性：active room 持久化、事件流紀錄、失效按鈕處理、Discord API 邊界錯誤處理、Bot 重啟恢復。

## 3. 產品定位

目前對外定位應聚焦於：幫 Discord 遊戲社群更穩定、更快速、更有秩序完成組隊的 LFG Bot。

短期不應主打信譽協議、HR Tech、玩家履歷或人格分析。這些可以保留為長期資料設計方向，但不進入 Alpha 2 與 Beta 1 的開發主線。

## 4. 技術棧與預期結構

### 4.1 目前技術棧

- Runtime：Node.js 18+
- Discord SDK：discord.js v14
- Keep-alive / health endpoint：Express
- Config：dotenv
- 短期儲存：JSON 檔案 + In-Memory Map
- 中期儲存：PostgreSQL / Redis，暫不進入 P0

### 4.2 建議最小檔案結構

```txt
Discord-Bot-Guard/
├── index.js
├── package.json
├── spec.md
├── .env.example
├── data/
│   ├── activeRooms.json
│   ├── events.jsonl
│   ├── logs.json
│   └── guildSettings.json
└── src/
    ├── config/
    │   └── constants.js
    ├── modules/
    │   ├── roomManager.js
    │   ├── roomPersistence.js
    │   ├── eventLogger.js
    │   ├── interactionModule.js
    │   ├── timerModule.js
    │   ├── embedBuilder.js
    │   ├── safeDiscord.js
    │   └── recovery.js
    └── utils/
        └── ids.js
```

若短期想維持單檔 `index.js`，也可以先不拆完整模組，但 `roomPersistence`、`eventLogger`、`safeDiscord` 的責任必須清楚存在，避免所有錯誤處理散落在 interaction handler 裡。

## 5. P0 必做內容

### P0-0：修正 repo 啟動阻塞

必做：修正 `package.json` JSON 語法，確認 `pnpm install` 可解析，確認 `pnpm start` 或 `node index.js` 有明確入口。

最低驗收：

```bash
pnpm install
pnpm start
```

不得因 package.json parse error 或 entry file missing 失敗。

### P0-1：Active Room 持久化

目前 active room 不應只存在 In-Memory Map。Bot 重啟後 Discord 上可能仍有舊房間公告，玩家點擊按鈕時 Bot 如果找不到 roomId，就會產生失效互動。

必做：

- 新增 `data/activeRooms.json`
- 建立房間後寫入 active room
- 玩家加入、退出、延長、關閉後更新 active room
- 房間關閉後從 activeRooms.json 移除
- 寫入失敗不得中斷 Discord 互動主流程，但必須寫入事件或 log

建議資料模型：

```json
{
  "roomId": {
    "id": "channelId-timestamp",
    "guildId": "guild_id",
    "guildName": "guild_name",
    "channelId": "channel_id",
    "messageId": "message_id",
    "driverId": "driver_id",
    "game": "Lethal Company",
    "maxPlayers": 5,
    "players": ["driver_id"],
    "status": "recruiting",
    "createdAt": "2026-05-04T00:00:00.000+08:00",
    "fullAt": null,
    "closeAt": null,
    "extendCount": 0,
    "invalid": false
  }
}
```

### P0-2：事件流紀錄 `events.jsonl`

`logs.json` 只適合做房間結束摘要，不適合作為未來信譽、防刷、行為分析的主資料源。短期應新增 append-only event log。

必做：

- 新增 `data/events.jsonl`
- 每一行是一筆 JSON，不使用整包 JSON array
- 所有房間操作都要寫入事件流
- 寫入失敗不得中斷主流程

必要事件類型：

```txt
room_created
room_updated
user_joined
user_left
room_filled
room_extended
room_closed
interaction_failed
message_update_failed
room_recovered
room_recovery_failed
```

事件格式：

```json
{
  "eventId": "evt_1714012800000_abcd",
  "type": "user_joined",
  "roomId": "channelId-timestamp",
  "guildId": "guild_id",
  "channelId": "channel_id",
  "userId": "user_id",
  "driverId": "driver_id",
  "game": "Lethal Company",
  "createdAt": "2026-05-04T00:00:00.000+08:00",
  "metadata": {
    "playerCount": 3,
    "maxPlayers": 5,
    "source": "original_guild"
  }
}
```

### P0-3：失效按鈕處理

所有 button interaction 都必須先檢查 roomId 是否存在、是否有效、是否已關閉。不能讓玩家點擊舊按鈕後無反應。

標準回覆：

```txt
此房間已失效或已結束，請重新建立發車房間。
```

要求：

- 回覆必須使用 ephemeral
- 寫入 `interaction_failed` event
- 不得 throw uncaught exception
- 不得嘗試更新不存在的 message

適用情境：

- Bot 重啟後 activeRooms 遺失
- 房間已關閉但舊訊息仍存在
- activeRooms.json 被刪除或損壞
- message 被手動刪除
- Discord interaction 延遲或重複觸發

### P0-4：Bot 啟動恢復 `recoverActiveRooms`

Bot ready 後需嘗試恢復 active rooms。

流程：

1. 讀取 `data/activeRooms.json`
2. 過濾明顯過期或 status 為 closed 的房間
3. 嘗試 fetch channel
4. 嘗試 fetch message
5. 若 message 存在，恢復 room 到 In-Memory Map
6. 根據 `status` 與 `closeAt` 重建 timer
7. 若 message 不存在或權限不足，標記 invalid，寫入 event
8. 輸出恢復摘要

恢復摘要格式：

```txt
Active room recovery completed:
- restored: 3
- expired: 2
- messageMissing: 1
- permissionFailed: 0
```

最低策略：若不能完整恢復，必須讓舊按鈕回覆「房間已失效」，不能無回應。

### P0-5：Discord API 安全包裝

所有 Discord API 操作都必須使用 try-catch 或 safe wrapper，不允許因單一訊息或權限錯誤讓 Bot 崩潰。

必要包裝：

- `client.channels.fetch`
- `channel.messages.fetch`
- `message.edit`
- `message.delete`
- `guild.members.fetch`
- `interaction.reply`
- `interaction.update`
- `interaction.deferReply`

建議回傳格式：

```js
return {
  success: false,
  code: 'MESSAGE_UPDATE_FAILED',
  error: error.message,
};
```

失敗事件需寫入 `events.jsonl`，例如 `message_update_failed` 或 `interaction_failed`。

## 6. Alpha 1 基礎功能清單

若目前尚未實作，需先補齊以下內容：

- `/開車` slash command
- 遊戲名稱參數
- 最大人數參數，範圍 2-20
- 備註參數，選填
- 建立房間公告 embed
- `我要排隊` button
- `取消排隊` button
- 司機關閉房間
- 玩家重複加入檢查
- 滿房檢查
- 司機退出時關閉房間
- 房間關閉時移除互動按鈕

## 7. Alpha 2 穩定版完成定義

Alpha 2 完成不是指能正常 demo，而是通過異常情境測試。

### 驗收 A：重啟測試

流程：

1. 建立房間
2. 加入至少 2 位玩家
3. 手動重啟 Bot
4. 點擊加入或退出按鈕

預期：房間可恢復，或明確回覆房間已失效；不得無回應、不得 crash、不得人數不同步。

### 驗收 B：失效房間測試

流程：

1. 建立房間
2. 手動刪除 `activeRooms.json` 中該房間
3. 點擊 Discord 舊房間按鈕

預期：ephemeral 回覆房間已失效，寫入 `interaction_failed`，Bot 不崩潰。

### 驗收 C：訊息刪除測試

流程：

1. 建立房間
2. 手動刪除 Discord 房間公告
3. 玩家互動或系統更新該房間

預期：捕捉 fetch/edit 失敗，寫入 `message_update_failed`，房間標記 invalid 或 closed，Bot 不崩潰。

### 驗收 D：事件流測試

流程：

1. 建立房間
2. 玩家加入
3. 玩家退出
4. 房間關閉
5. 檢查 `events.jsonl`

預期至少包含：

```txt
room_created
user_joined
user_left
room_closed
```

每筆事件必須包含 `eventId`、`type`、`roomId`、`guildId`、`createdAt`、`metadata`。

## 8. Beta 1：跨伺服器免費測試版

Beta 1 必須等 Alpha 2 完成後再進入。跨伺服器第一版只做中央曝光與導流看板，不做完整跨服配對網。

核心原則：

1. 原伺服器是房間狀態唯一真實來源。
2. 中央招募頻道只做曝光與導流。
3. 中央訊息同步失敗不得影響原伺服器房間。
4. 玩家不在原伺服器時，提示加入原伺服器。
5. 真正排隊仍以原伺服器狀態為準。
6. 所有跨伺服器操作都必須寫入事件流。

Beta 1 待做：

- `CENTRAL_SERVER_ID`
- `RECRUIT_CHANNEL_ID`
- `/設定 invite_url`
- `guildSettings.json`
- 中央招募 embed
- 中央訊息同步更新
- 中央訊息刪除或失效處理
- 玩家是否在原伺服器的 member fetch 檢查
- 邀請連結 ephemeral 提示

## 9. Beta 2：留存增強版

Beta 2 不阻塞 Beta 1。候選內容：

- 氣氛標籤
- 常用遊戲模板
- 房間統計
- 正向徽章或感謝紀錄
- 伺服器活躍報表
- 管理員設定預設遊戲清單

這一階段可以開始觀察高頻社群，準備用戶訪談。

## 10. 暫緩項目

以下項目不屬於 P0，也不應阻塞 Alpha 2。

### 10.1 信譽分

暫不實作：

- 0-100 公開信譽分
- 負評懲罰
- 黑名單自動化
- 抽籤權重
- 排行榜

允許保留：

- 事件資料
- 完成場次
- 感謝紀錄
- 正向徽章
- 常玩遊戲標籤

### 10.2 HR Tech

暫不實作：

- 行為履歷
- 面試報告
- 軟實力分析
- LLM 評估玩家人格
- 對外 HR Tech 敘事

允許保留：

- 事件資料設計
- 評價來源
- 行為軌跡
- 未來語意轉譯可能性

### 10.3 預約抽籤系統

預約抽籤系統可作為 Paid 1 候選功能，但需要等免費 Beta 有基本使用量與用戶訪談後再決定。

暫不實作：

- `/預約發車`
- 報名截止
- 自動抽籤
- VIP 名額
- 候補遞補
- Twitch / YouTube API

可保留於產品藍圖：

- 實況主觀眾場
- VIP 角色整合
- 候補名單
- 主辦者管理面板
- 活動出席確認

## 11. 建議開發順序

第一優先：

1. 修正 `package.json`
2. 補齊或確認 `index.js`
3. 建立 `data/activeRooms.json`
4. 建立 `data/events.jsonl`
5. 實作 stale button handler
6. 實作 recoverActiveRooms
7. 實作 Discord API safe wrapper

第二優先：

1. 房間狀態測試
2. 訊息刪除測試
3. Bot 重啟測試
4. 權限不足測試
5. interaction 重複回覆測試

第三優先：

1. 單伺服器 UX 補強
2. 氣氛標籤
3. 遊戲模板
4. 中央招募架構

## 12. 已知工程風險

- `package.json` 目前不可被正常 JSON parser 解析。
- `package.json.main` 指向 `index.js`，但目前未確認該入口存在。
- 若 activeRooms 僅存在記憶體，Bot 重啟後舊按鈕一定會有狀態遺失風險。
- 若沒有 `events.jsonl`，未來很難做信譽、防刷、統計與錯誤追蹤。
- 若跨伺服器功能在 P0 前導入，會把狀態一致性問題放大。

## 13. 當前任務定義

目前任務不是新增大型產品功能，而是讓單伺服器 LFG Bot 具備可恢復、可追蹤、可失敗但不崩潰的工程地基。

完成 P0 後，再進入跨伺服器 Beta 1。完成 Beta 1 後，再根據真實社群使用情況決定 Beta 2 留存功能與 Paid 1 預約抽籤系統。

---

**最後更新：** 2026-05-04 00:00 Asia/Taipei
