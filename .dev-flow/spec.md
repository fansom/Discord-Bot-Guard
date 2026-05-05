# Spec：Active Room 穩定性修正

## 1. 目標
本 spec 只描述目前要實作的單一功能：讓 Discord 發車房間在 Bot 重啟、舊按鈕、訊息刪除、權限不足、資料恢復失敗時仍能穩定回應。

不包含跨伺服器、信譽分、HR Tech、預約抽籤、PostgreSQL/Redis。階段 1 依 Framework 慣例使用 JSON 檔案儲存，並遵循單一職責、低耦合、高內聚、易測試的模組化設計。

## 2. 架構原則
即時狀態仍放在 `roomManager` 的 In-Memory Map；恢復層寫入 `data/activeRooms.json`；長期事件流寫入 `data/events.jsonl`。`logs.json` 只保留房間結束摘要，不作為本功能主資料源。

本功能沿用既有模組命名與檔案慣例：`src/modules/*.js` 放核心模組，`src/config/*.js` 放常數與選項，`data/*.json` 放階段 1 資料。

## 3. 需要修改的檔案

### `package.json`
修正 JSON 語法錯誤，確保可執行：
```bash
pnpm install
pnpm start
```
需保留或補上：
```json
{"main":"index.js","scripts":{"start":"node index.js","dev":"nodemon index.js"}}
```

### `index.js`
若不存在，新增 root 入口；若已存在，調整為轉接 `src/index.js`：
```js
require('./src/index');
```

### `src/index.js`
在 Bot ready 後呼叫 `recoverActiveRooms(client, roomManager)`。`interactionCreate` 只負責分流到 command/button handler，不直接操作檔案或 Discord message。Discord API 操作需透過 `safeDiscord.js` 或同等 try-catch wrapper。

### `src/modules/roomManager.js`
在狀態變更時同步 persistence 與 event：
- `createRoom`：寫入 active room，記錄 `room_created`
- `joinRoom`：更新 active room，記錄 `user_joined`
- `leaveRoom`：更新 active room，記錄 `user_left`
- `extendRoom`：更新 active room，記錄 `room_extended`
- `closeRoom`：移除 active room，記錄 `room_closed`

### `src/modules/interactionModule.js`
所有 button handler 開頭必須檢查 room 是否存在、invalid、closed。失效時回覆 ephemeral：
```txt
此房間已失效或已結束，請重新建立發車房間。
```
並寫入 `interaction_failed`。

### `src/modules/timerModule.js`
恢復房間後需能重建 timer。close、invalid、recover failure 時需清除相關 timer，避免重複觸發。

## 4. 需要新增的檔案

### `data/activeRooms.json`
初始內容：
```json
{}
```
用途：儲存 active room 快照，供 Bot 重啟後恢復。

資料格式：
```json
{
  "roomId": {
    "id": "channelId-timestamp",
    "guildId": "guild_id",
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

### `data/events.jsonl`
初始可為空檔。每行一筆 JSON，不使用 JSON array。

必要事件：`room_created`、`room_updated`、`user_joined`、`user_left`、`room_filled`、`room_extended`、`room_closed`、`interaction_failed`、`message_update_failed`、`room_recovered`、`room_recovery_failed`。

範例：
```json
{"eventId":"evt_...","type":"user_joined","roomId":"...","guildId":"...","createdAt":"...","metadata":{"playerCount":3}}
```

### `src/modules/roomPersistence.js`
負責 `activeRooms.json` 讀寫。API：
```js
loadActiveRooms()
saveActiveRooms(activeRoomsMap)
saveActiveRoom(roomData)
removeActiveRoom(roomId)
markRoomInvalid(roomId, reason)
```
寫入建議採 atomic write：先寫 `.tmp`，成功後 rename。

### `src/modules/eventLogger.js`
負責 `events.jsonl`。API：
```js
appendEvent(type, payload)
createEventId()
```
事件寫入失敗不得中斷主流程，只能 console warn。

### `src/modules/safeDiscord.js`
包裝 Discord API 錯誤。API：
```js
safeFetchChannel(client, channelId)
safeFetchMessage(channel, messageId)
safeEditMessage(message, payload)
safeDeleteMessage(message)
safeReplyInteraction(interaction, payload)
safeUpdateInteraction(interaction, payload)
```
回傳：`{ success: true, data }` 或 `{ success: false, code, error }`。

### `src/modules/recovery.js`
Bot ready 後恢復 active rooms。API：
```js
recoverActiveRooms(client, roomManager)
```
流程：讀取 `activeRooms.json`，過濾 closed/過期房間，fetch channel/message。成功則放回 roomManager 的 activeRooms Map 並重建 timer；失敗則標記 invalid 並寫入 `room_recovery_failed`。

## 5. 驗收條件

A. 啟動測試：`pnpm install && pnpm start` 不得因 package parse error 或 entry missing 失敗。

B. 重啟恢復：建立房間並加入玩家後重啟 Bot。重啟後點擊加入或退出，房間應可恢復；若不可恢復，必須 ephemeral 回覆房間已失效。

C. 失效按鈕：刪除 `activeRooms.json` 中某房間後點舊按鈕。Bot 必須回覆房間已失效，寫入 `interaction_failed`，不得 crash。

D. 訊息刪除：建立房間後手動刪除 Discord 公告，再觸發更新。Bot 必須捕捉 fetch/edit 失敗，寫入 `message_update_failed`，並將房間標記 invalid 或 closed。

E. 事件流：建立房間、加入、退出、關閉後，`events.jsonl` 至少包含 `room_created`、`user_joined`、`user_left`、`room_closed`。

## 6. 開發順序
1. 修正 `package.json`
2. 補齊 root `index.js`
3. 新增 `data/activeRooms.json`
4. 新增 `data/events.jsonl`
5. 新增 `roomPersistence.js`
6. 新增 `eventLogger.js`
7. 新增 `safeDiscord.js`
8. 修改 `roomManager.js`
9. 修改 `interactionModule.js`
10. 新增 `recovery.js`
11. 修改 `src/index.js` ready flow
12. 補驗收測試

---
**最後更新：** 2026-05-04 00:00 Asia/Taipei
