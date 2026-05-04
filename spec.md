# PersonaLink / Discord-Bot-Guard 專案規格與進度盤點

## 1. 文件目的

本文件用來記錄 Discord-Bot-Guard（目前產品方向對齊 PersonaLink Discord LFG Bot）的實際開發狀態、短期工程目標、已知待做內容與暫緩項目。文件重點不是長期願景，而是讓目前 repo 能進入可穩定測試的 Alpha 2 / Beta 前置狀態。

目前短期目標是完成 P0 穩定性地基：讓單伺服器發車流程在 Bot 重啟、舊按鈕、訊息刪除、權限不足、資料恢復失敗等異常情境下仍能穩定回應，不崩潰、不無回應、不產生錯誤狀態。

本版已導入 `PersonaLink_Development_Framework.md` 的設計，將其整理為「預計執行內容」。這些內容代表接下來的工程落地目標，不代表目前 repo 已全部完成。

## 2. 目前可確認進度

### 2.1 Repo 狀態

目前 repo 已有 `package.json`，專案名稱為 `personalink-bot`，描述為 `Discord 自動發車 Bot`，主入口設定為 `index.js`，技術方向使用 Node.js、Discord.js v14、Express、dotenv。

目前可確認的阻塞點：`package.json` 內容存在 JSON 語法錯誤，`scripts.start` 後缺少逗號，`devDependencies.dotenv` 後也缺少逗號。這會導致套件管理器無法正常解析 package.json，屬於啟動前必修問題。

目前未在 repo root 確認到 `index.js`。由於 `package.json.main` 指向 `index.js`，若該檔案尚未存在，`pnpm start` 或 `node index.js` 會直接失敗。

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

### 4.2 Development Framework 導入後的預計檔案結構

`PersonaLink_Development_Framework.md` 原始設計採本地開發版結構，目標是 15-20 個檔案、800-1200 行程式碼。導入 spec 後，建議以此作為 repo 的中期結構，但加入 P0 需要的 `activeRooms.json`、`events.jsonl`、`roomPersistence.js`、`eventLogger.js`、`safeDiscord.js`、`recovery.js`。

```txt
Discord-Bot-Guard/
├── index.js                         # repo root 啟動入口；可轉接 src/index.js
├── package.json
├── spec.md
├── .env
├── .env.example
├── .gitignore
├── README.md
├── data/
│   ├── activeRooms.json             # P0：活躍房間恢復層
│   ├── events.jsonl                 # P0：append-only 事件流
│   ├── logs.json                    # 房間結束摘要
│   └── guildSettings.json           # 伺服器設定與邀請連結
├── src/
│   ├── index.js                     # Discord Client、指令註冊、事件監聽、Express keep-alive
│   ├── config/
│   │   ├── constants.js             # 時間、顏色、限制、錯誤訊息
│   │   └── gameChoices.js           # 遊戲選項列表
│   ├── modules/
│   │   ├── commandModule.js         # slash command 處理
│   │   ├── interactionModule.js     # button interaction 處理
│   │   ├── roomManager.js           # 房間 CRUD 與狀態管理
│   │   ├── roomPersistence.js       # activeRooms.json 讀寫
│   │   ├── recovery.js              # recoverActiveRooms
│   │   ├── timerModule.js           # zombie/full/warning/close timer
│   │   ├── crossServerModule.js     # Beta 1：中央招募頻道同步
│   │   ├── embedBuilder.js          # Discord embed 產生器
│   │   ├── fileManager.js           # logs.json、guildSettings.json 讀寫
│   │   ├── eventLogger.js           # events.jsonl append-only logger
│   │   ├── safeDiscord.js           # Discord API safe wrapper
│   │   ├── logger.js                # console / file log 包裝
│   │   └── validation.js            # user/room/join 驗證
│   └── utils/
│       ├── errorHandler.js
│       ├── helpers.js
│       └── ids.js
└── tests/
    ├── unit/
    └── integration/
```

短期可以先用單檔或少量模組完成，但職責必須對齊上面結構。尤其 P0 相關的 persistence、event log、safe wrapper、recovery 不應被省略。

## 5. 開發環境與啟動規格

### 5.1 系統需求

- Node.js >= 18.0.0
- pnpm 或 npm；目前 repo 有 pnpm preinstall 限制，需先修正 package.json 後再確認最終套件管理器
- Git
- Discord Developer Account
- 至少一個 Discord 測試伺服器

### 5.2 預計依賴

```bash
pnpm add discord.js@14.14.1 express@4.18.2 dotenv@16.3.1
pnpm add -D eslint prettier eslint-config-prettier nodemon
```

若維持 npm，需移除或調整 `preinstall` 的 pnpm 強制限制。若維持 pnpm，則 README 與 spec 都以 pnpm 為準。

### 5.3 `.env.example` 預計內容

```env
DISCORD_TOKEN=YOUR_DISCORD_BOT_TOKEN_HERE
CENTRAL_SERVER_ID=YOUR_CENTRAL_SERVER_ID
RECRUIT_CHANNEL_ID=YOUR_RECRUIT_CHANNEL_ID
PORT=3000
NODE_ENV=development
ENABLE_CROSS_SERVER=false
ENABLE_AUTO_CLOSE=true
LOG_LEVEL=debug
```

P0 階段建議 `ENABLE_CROSS_SERVER=false`，避免在單伺服器穩定性完成前引入跨服同步複雜度。

### 5.4 預計啟動指令

```bash
pnpm install
pnpm dev
pnpm start
```

預計 `package.json` scripts：

```json
{
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "lint": "eslint .",
    "format": "prettier --write .",
    "test": "node --test"
  }
}
```

## 6. P0 必做內容

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

## 7. Development Framework 預計執行內容

### 7.1 `src/index.js` 主程式入口

職責：初始化 Discord Client、註冊 slash commands、監聽 interaction、啟動 Express keep-alive、在 ready 後執行 `recoverActiveRooms`。

預計流程：

1. 載入 `.env`
2. 初始化 Discord Client，至少使用 `GatewayIntentBits.Guilds`
3. 啟動 Express health endpoint，例如 `GET /` 與 `GET /metrics`
4. `client.once('ready')` 中註冊指令、恢復 active rooms、輸出啟動 log
5. `client.on('interactionCreate')` 分流到 command/button handlers
6. 使用 safe wrapper 處理所有 Discord API 操作

### 7.2 `src/config/constants.js`

預計集中管理時間、顏色、狀態、限制、錯誤訊息。

```js
module.exports = {
  TIMEOUT_CONFIG: {
    ZOMBIE_ROOM_TIMEOUT: 2 * 60 * 60 * 1000,
    FULL_ROOM_DURATION: 45 * 60 * 1000,
    WARNING_TIME: 5 * 60 * 1000,
    EXTEND_TIME: 30 * 60 * 1000,
    DELETE_DELAY: 10 * 60 * 1000,
    MAX_EXTENDS: 2,
  },
  COLORS: {
    RECRUITING: 0x00ff00,
    FULL: 0xff0000,
    ENDING: 0xff9900,
    CLOSED: 0x808080,
  },
  ROOM_STATUS: {
    RECRUITING: 'recruiting',
    FULL: 'full',
    ENDING: 'ending',
    CLOSED: 'closed',
  },
  LIMITS: {
    MIN_PLAYERS: 2,
    MAX_PLAYERS: 20,
    MAX_CONCURRENT_ROOMS_PER_USER: 1,
    MAX_ROOMS_PER_DAY: 10,
    COOLDOWN_AFTER_CANCEL: 300,
  },
};
```

### 7.3 `src/config/gameChoices.js`

預計提供 slash command 遊戲選項。初版可以保留常見遊戲與 `其他`。

```js
module.exports = [
  { name: '🎮 傳說對決', value: '傳說對決' },
  { name: '🎮 英雄聯盟', value: '英雄聯盟' },
  { name: '🎮 APEX Legends', value: 'APEX' },
  { name: '🎮 VALORANT', value: 'VALORANT' },
  { name: '🎮 Lethal Company', value: 'Lethal Company' },
  { name: '🎯 其他遊戲', value: '其他' },
];
```

### 7.4 `commandModule.js`

預計處理：

- `/開車 game max_players note`
- `/設定 invite_url`，Beta 1 使用

`/開車` 必須做基本驗證：人數範圍、使用者是否已有活躍房間、頻道權限、Bot 是否可發送 embed 與 button。

`/設定 invite_url` 在 Alpha 2 可先放入 backlog，Beta 1 前實作。該指令需驗證 Discord invite URL 格式，並寫入 `guildSettings.json`。

### 7.5 `interactionModule.js`

預計處理 button customId：

```txt
join_{roomId}
leave_{roomId}
extend_{roomId}
close_{roomId}
```

所有 handler 第一行必須做 stale room 檢查。若 room 不存在、invalid、closed，回覆 ephemeral：「此房間已失效或已結束，請重新建立發車房間。」並寫入 `interaction_failed`。

### 7.6 `roomManager.js`

預計 API：

```js
createRoom(options)       // 建立 roomData，加入 activeRooms，寫入 persistence/event
joinRoom(roomId, userId)  // 加入玩家，檢查重複/滿房/狀態
leaveRoom(roomId, userId) // 移除玩家，司機退出則關閉房間
extendRoom(roomId)        // 延長房間時間，最多 MAX_EXTENDS
closeRoom(roomId, reason) // 關閉房間，清 timer、更新訊息、寫入事件、移除 persistence
getRoomData(roomId)       // 取得 roomData 或 null
```

`joinRoom` 回傳格式：

```js
{ success: true, isFull: false, currentPlayers: 2 }
```

`extendRoom` 回傳格式：

```js
{ success: true, remainingExtends: 1 }
```

錯誤回傳格式：

```js
{ success: false, code: 'ROOM_FULL', message: '房間已滿' }
```

### 7.7 `timerModule.js`

預計 API：

```js
setZombieTimer(roomId)
setAutoCloseTimer(roomId)
setWarningTimer(roomId)
clearAllTimers(roomId)
```

規格：

- 房間建立時設定 zombie timer
- 第一位非司機玩家加入後清除 zombie timer
- 人滿後設定 full duration close timer
- 關閉前 5 分鐘切換 `ending`
- 延長時清除舊 timer 並重設
- room 被關閉或 invalid 時必須清除所有 timer

### 7.8 `embedBuilder.js`

預計 API：

```js
createRecruitingEmbed(roomData)
createFullEmbed(roomData)
createEndingEmbed(roomData)
createClosedEmbed(roomData, reason)
```

狀態顏色：

- recruiting：綠色
- full：紅色
- ending：橘色
- closed：灰色

Embed 必須顯示：遊戲、人數、狀態、司機、隊員名單、備註（如有）、來源伺服器。full / ending 狀態需顯示剩餘時間。

### 7.9 `fileManager.js`

預計處理：

```js
saveLog(logEntry)
readLogs()
saveGuildSettings(guildId, settings)
getGuildSettings(guildId)
getGuildInviteUrl(guildId)
```

`logs.json` 僅作房間結束摘要，不取代 `events.jsonl`。

### 7.10 `roomPersistence.js`

P0 新增模組，負責 `activeRooms.json`。

預計 API：

```js
loadActiveRooms()
saveActiveRooms(activeRoomsMap)
saveActiveRoom(roomData)
removeActiveRoom(roomId)
markRoomInvalid(roomId, reason)
```

寫入建議採 atomic write：先寫 `.tmp`，成功後 rename，降低 JSON 損壞機率。

### 7.11 `eventLogger.js`

P0 新增模組，負責 `events.jsonl`。

預計 API：

```js
appendEvent(type, payload)
createEventId()
```

事件寫入失敗不可中斷主流程，但要 console warn。事件時間使用 Asia/Taipei 可讀時間或 ISO UTC 皆可；建議統一 ISO string，metadata 補 timezone。

### 7.12 `safeDiscord.js`

P0 新增模組，包裝 Discord API。

預計 API：

```js
safeFetchChannel(client, channelId)
safeFetchMessage(channel, messageId)
safeEditMessage(message, payload)
safeDeleteMessage(message)
safeReplyInteraction(interaction, payload)
safeUpdateInteraction(interaction, payload)
safeFetchGuildMember(guild, userId)
```

每個函數回傳 `{ success, data?, code?, error? }`，失敗時寫入事件由上層決定。

### 7.13 `recovery.js`

P0 新增模組，負責 Bot ready 後恢復房間。

預計 API：

```js
recoverActiveRooms(client, roomManager)
```

輸出摘要：restored、expired、messageMissing、permissionFailed、invalid。

### 7.14 `crossServerModule.js`

Beta 1 才執行。預計 API：

```js
postToCentralServer(roomData, embed, buttons)
updateCentralMessage(roomData, embed, buttons)
deleteCentralMessage(roomData)
isUserInGuild(userId, guildId)
sendInvitePrompt(interaction, guildId, guildName)
```

跨伺服器模組不得影響原伺服器流程；中央訊息失敗只寫 event，不中斷 room operation。

## 8. Alpha 1 基礎功能清單

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

## 9. Alpha 2 穩定版完成定義

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

## 10. 測試計畫

### 10.1 手動測試

基礎功能：

- [ ] `/開車` 指令能正常觸發
- [ ] 公告正確顯示遊戲名稱、人數、司機、備註
- [ ] 按鈕可點擊
- [ ] 人數正確累加
- [ ] 玩家可退出
- [ ] 人滿通知正常
- [ ] 自動關閉機制正常

邊界測試：

- [ ] 重複點擊加入
- [ ] 滿房時點擊加入
- [ ] 非司機點延長
- [ ] 司機退出房間
- [ ] 訊息被刪除時的處理
- [ ] Bot 重啟後舊按鈕處理
- [ ] activeRooms.json 損壞或缺失

跨伺服器測試，Beta 1：

- [ ] 中央伺服器接收公告
- [ ] 公告同步更新
- [ ] 邀請連結正常
- [ ] 中央訊息同步失敗不影響原房間

### 10.2 單元測試

優先測：

- `roomManager.createRoom`
- `roomManager.joinRoom`
- `roomManager.leaveRoom`
- `roomManager.extendRoom`
- `roomPersistence.load/save/remove`
- `eventLogger.appendEvent`
- `validation.canUserJoin`

### 10.3 整合測試

優先測：

- 建房 → 加入 → 人滿 → 自動 close
- 建房 → 重啟 → recover → 加入
- 建房 → 刪 message → interaction → invalid
- 建房 → activeRooms.json 刪除 → stale button response

## 11. 開發規範

### 11.1 程式碼風格

預計使用 ESLint + Prettier。

`.prettierrc` 建議：

```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
```

命名規範：

- 常數：`UPPER_SNAKE_CASE`
- 變數 / 函數：`camelCase`
- 類別：`PascalCase`
- 檔案：`camelCase.js`
- 私有輔助函數：可使用 `_prefix`

### 11.2 錯誤處理

所有 async Discord API 操作都必須 try-catch。錯誤不可吞掉；要回傳 normalized result，必要時寫入 `events.jsonl`。

### 11.3 Git commit 規範

```txt
feat(scope): 新功能
fix(scope): 修復 Bug
docs(scope): 文件更新
refactor(scope): 重構
test(scope): 測試
chore(scope): 工具或依賴
```

範例：

```bash
git commit -m "fix(package): repair package json syntax"
git commit -m "feat(room): persist active rooms"
git commit -m "feat(events): add jsonl event logger"
```

## 12. 部署規格

### 12.1 本地部署

```bash
pnpm install
cp .env.example .env
pnpm start
```

### 12.2 Replit 部署

- 匯入 GitHub repo
- 設定 Secrets：`DISCORD_TOKEN`、未來的 `CENTRAL_SERVER_ID`、`RECRUIT_CHANNEL_ID`
- 確認 Express health endpoint 正常
- 可用 UptimeRobot 監控 Replit URL

### 12.3 VPS 部署，未來

- 使用 PM2 管理 process
- `.env` 放在 server，不提交 Git
- data 檔案需備份或遷移到 PostgreSQL

## 13. Beta 1：跨伺服器免費測試版

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

## 14. Beta 2：留存增強版

Beta 2 不阻塞 Beta 1。候選內容：

- 氣氛標籤
- 常用遊戲模板
- 房間統計
- 正向徽章或感謝紀錄
- 伺服器活躍報表
- 管理員設定預設遊戲清單

這一階段可以開始觀察高頻社群，準備用戶訪談。

## 15. 暫緩項目

以下項目不屬於 P0，也不應阻塞 Alpha 2。

### 15.1 信譽分

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

### 15.2 HR Tech

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

### 15.3 預約抽籤系統

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

## 16. 建議開發順序

第一優先：

1. 修正 `package.json`
2. 補齊或確認 `index.js`
3. 建立 `.env.example`
4. 建立 `src/index.js` 或 root `index.js`
5. 建立 `src/config/constants.js`
6. 建立 `data/activeRooms.json`
7. 建立 `data/events.jsonl`
8. 實作 `roomPersistence.js`
9. 實作 `eventLogger.js`
10. 實作 stale button handler
11. 實作 `recoverActiveRooms`
12. 實作 `safeDiscord.js`

第二優先：

1. `roomManager.js`
2. `timerModule.js`
3. `embedBuilder.js`
4. `fileManager.js`
5. `commandModule.js`
6. `interactionModule.js`
7. 房間狀態測試
8. 訊息刪除測試
9. Bot 重啟測試
10. 權限不足測試

第三優先：

1. 單伺服器 UX 補強
2. 氣氛標籤
3. 遊戲模板
4. 中央招募架構

## 17. 已知工程風險

- `package.json` 目前不可被正常 JSON parser 解析。
- `package.json.main` 指向 `index.js`，但目前未確認該入口存在。
- 若 activeRooms 僅存在記憶體，Bot 重啟後舊按鈕一定會有狀態遺失風險。
- 若沒有 `events.jsonl`，未來很難做信譽、防刷、統計與錯誤追蹤。
- 若跨伺服器功能在 P0 前導入，會把狀態一致性問題放大。
- Development Framework 內原本有跨伺服器與自動關閉內容，但目前應先完成 P0，再打開跨服功能。

## 18. 當前任務定義

目前任務不是新增大型產品功能，而是讓單伺服器 LFG Bot 具備可恢復、可追蹤、可失敗但不崩潰的工程地基。

完成 P0 後，再進入跨伺服器 Beta 1。完成 Beta 1 後，再根據真實社群使用情況決定 Beta 2 留存功能與 Paid 1 預約抽籤系統。

---

**最後更新：** 2026-05-04 00:00 Asia/Taipei
