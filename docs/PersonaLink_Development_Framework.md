# PersonaLink 本地開發框架文件

**專案名稱：** PersonaLink Discord LFG Bot  
**版本：** V2.0 - 本地開發版  
**最後更新：** 2025-04-24  
**開發環境：** 本地 (從 Replit 遷移)

---

## 📋 目錄

1. [專案概述](#1-專案概述)
2. [專案結構](#2-專案結構)
3. [開發環境設定](#3-開發環境設定)
4. [核心模組說明](#4-核心模組說明)
5. [API 參考](#5-api-參考)
6. [開發規範](#6-開發規範)
7. [測試指南](#7-測試指南)
8. [部署流程](#8-部署流程)
9. [常見問題](#9-常見問題)

---

## 1. 專案概述

### 1.1 專案簡介

PersonaLink 是一個 Discord LFG (Looking For Group) 機器人，專注於：
- **極速組隊**：3 秒發車，零學習成本
- **智能預設**：開箱即用，進階可調
- **跨伺服器招募**：自動推送到中央招募頻道
- **數據驅動**：玩家履歷、評價系統（階段 2）

### 1.2 技術棧

```
運行環境：Node.js 18+
核心框架：Discord.js v14
API 框架：Express (Keep-alive)
資料儲存：JSON 檔案 (階段 1) → PostgreSQL (階段 2)
部署平台：本地開發 → Replit/VPS
```

### 1.3 開發階段

```
當前階段：階段 1 - MVP
├─ 核心功能：快速發車、跨伺服器、自動關閉
├─ 資料儲存：JSON + In-Memory Map
└─ 目標：驗證商業模式，獲取前 10 個客戶

未來階段：
├─ 階段 2：數據黏性（玩家履歷、評價、戰隊）
└─ 階段 3：HR Tech（人才市場、技能認證）
```

---

## 2. 專案結構

### 2.1 檔案樹狀圖

```
personalink-bot/
├── src/
│   ├── index.js                 # 主程式入口
│   ├── config/
│   │   ├── constants.js         # 常數設定（時間、顏色、限制）
│   │   └── gameChoices.js       # 遊戲選項列表
│   ├── modules/
│   │   ├── commandModule.js     # 指令處理模組
│   │   ├── interactionModule.js # 按鈕互動處理
│   │   ├── roomManager.js       # 房間管理核心
│   │   ├── timerModule.js       # 計時器管理
│   │   ├── crossServerModule.js # 跨伺服器功能
│   │   ├── embedBuilder.js      # Embed 生成器
│   │   ├── fileManager.js       # 檔案讀寫管理
│   │   ├── logger.js            # 日誌系統
│   │   └── validation.js        # 驗證模組
│   └── utils/
│       ├── errorHandler.js      # 錯誤處理
│       └── helpers.js           # 輔助函數
├── data/
│   ├── logs.json                # 發車記錄（自動生成）
│   └── guildSettings.json       # 伺服器設定（自動生成）
├── tests/
│   ├── unit/                    # 單元測試
│   └── integration/             # 整合測試
├── docs/
│   ├── PersonaLink_V2_Architecture.md    # 系統架構文件
│   └── PersonaLink_Development_Framework.md  # 本文件
├── .env                         # 環境變數（不提交到 Git）
├── .env.example                 # 環境變數範例
├── .gitignore                   # Git 忽略清單
├── package.json                 # 專案依賴
├── package-lock.json            # 鎖定依賴版本
└── README.md                    # 專案說明

預計檔案數：15-20 個（階段 1）
預計程式碼行數：800-1200 行
```

### 2.2 模組化設計原則

```
原則 1：單一職責
每個模組只負責一個功能領域

原則 2：低耦合
模組之間通過清晰的介面通訊

原則 3：高內聚
相關功能集中在同一模組

原則 4：易測試
每個函數都應該可獨立測試
```

---

## 3. 開發環境設定

### 3.1 系統需求

```
必要：
├─ Node.js >= 18.0.0
├─ npm >= 9.0.0
└─ Git

推薦：
├─ VS Code (編輯器)
├─ Discord Developer Account
└─ 至少一個 Discord 測試伺服器
```

### 3.2 初始化專案

```bash
# 1. 克隆專案（如果有 Git）
git clone <repository-url>
cd personalink-bot

# 2. 或從 Replit 下載後初始化
cd personalink-bot
npm init -y  # 如果沒有 package.json

# 3. 安裝依賴
npm install discord.js@14.14.1 express@4.18.2 dotenv@16.3.1

# 4. 建立環境變數檔案
cp .env.example .env

# 5. 編輯 .env，填入你的 Discord Token
# DISCORD_TOKEN=your_token_here
# CENTRAL_SERVER_ID=your_central_server_id
# RECRUIT_CHANNEL_ID=your_recruit_channel_id
```

### 3.3 環境變數說明

**.env 檔案內容：**

```env
# ===== Discord Bot 設定 =====
# 必填：從 Discord Developer Portal 取得
DISCORD_TOKEN=MTQ5NjI1MDM0NzQ5MTI2MTc0.GxTgua.example_token

# ===== 中央伺服器設定 =====
# 選填：如果不啟用跨伺服器功能可留空
CENTRAL_SERVER_ID=1234567890123456789
RECRUIT_CHANNEL_ID=9876543210987654321

# ===== Express 伺服器設定 =====
# 選填：預設 3000
PORT=3000

# ===== 開發模式設定 =====
# development | production
NODE_ENV=development

# ===== 功能開關 =====
# 是否啟用跨伺服器招募
ENABLE_CROSS_SERVER=true

# 是否啟用自動關閉機制
ENABLE_AUTO_CLOSE=true

# ===== 日誌設定 =====
# 日誌等級：debug | info | warn | error
LOG_LEVEL=debug
```

**.env.example 範例：**

```env
DISCORD_TOKEN=YOUR_DISCORD_BOT_TOKEN_HERE
CENTRAL_SERVER_ID=YOUR_CENTRAL_SERVER_ID
RECRUIT_CHANNEL_ID=YOUR_RECRUIT_CHANNEL_ID
PORT=3000
NODE_ENV=development
ENABLE_CROSS_SERVER=true
ENABLE_AUTO_CLOSE=true
LOG_LEVEL=debug
```

### 3.4 啟動開發伺服器

```bash
# 開發模式（自動重啟）
npm run dev

# 或使用 nodemon（需要安裝）
npm install -g nodemon
nodemon src/index.js

# 正式模式
npm start
```

### 3.5 推薦的 VS Code 擴充功能

```json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",      // ESLint
    "esbenp.prettier-vscode",      // Prettier
    "ms-vscode.vscode-json",       // JSON 工具
    "PKief.material-icon-theme",   // 圖示主題
    "usernamehw.errorlens"         // 即時錯誤提示
  ]
}
```

---

## 4. 核心模組說明

### 4.1 index.js（主程式入口）

**職責：**
- 初始化 Discord Client
- 註冊斜線指令
- 監聽事件
- 啟動 Express Keep-alive 伺服器

**主要流程：**

```javascript
// 1. 載入環境變數與設定
require('dotenv').config();
const { Client, GatewayIntentBits } = require('discord.js');

// 2. 初始化 Client
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent
  ]
});

// 3. Bot 啟動事件
client.once('ready', async () => {
  console.log(`✅ Bot 已上線: ${client.user.tag}`);
  await registerCommands(client);
});

// 4. 指令處理
client.on('interactionCreate', async (interaction) => {
  if (interaction.isChatInputCommand()) {
    await handleCommand(interaction);
  }
  if (interaction.isButton()) {
    await handleButton(interaction);
  }
});

// 5. 登入
client.login(process.env.DISCORD_TOKEN);
```

---

### 4.2 config/constants.js（常數設定）

**職責：** 集中管理所有常數設定

**內容結構：**

```javascript
module.exports = {
  // 時間設定（毫秒）
  TIMEOUT_CONFIG: {
    ZOMBIE_ROOM_TIMEOUT: 2 * 60 * 60 * 1000,   // 2 小時
    FULL_ROOM_DURATION: 45 * 60 * 1000,        // 45 分鐘
    WARNING_TIME: 5 * 60 * 1000,               // 5 分鐘
    EXTEND_TIME: 30 * 60 * 1000,               // 30 分鐘
    DELETE_DELAY: 10 * 60 * 1000,              // 10 分鐘
    MAX_EXTENDS: 2                             // 最多延長次數
  },

  // 顏色設定
  COLORS: {
    RECRUITING: 0x00ff00,  // 綠色
    FULL: 0xff0000,        // 紅色
    ENDING: 0xff9900,      // 橘色
    CLOSED: 0x808080       // 灰色
  },

  // 房間狀態
  ROOM_STATUS: {
    RECRUITING: 'recruiting',
    FULL: 'full',
    ENDING: 'ending',
    CLOSED: 'closed'
  },

  // 限制設定
  LIMITS: {
    MIN_PLAYERS: 2,
    MAX_PLAYERS: 20,
    MAX_CONCURRENT_ROOMS_PER_USER: 1,
    MAX_ROOMS_PER_DAY: 10,
    COOLDOWN_AFTER_CANCEL: 300  // 秒
  },

  // 錯誤訊息
  ERROR_MESSAGES: {
    ROOM_NOT_FOUND: '❌ 房間不存在或已關閉',
    ALREADY_IN_ROOM: '⚠️ 你已經在隊伍中了',
    ROOM_FULL: '❌ 房間已滿',
    NOT_IN_ROOM: '⚠️ 你不在隊伍中',
    NOT_DRIVER: '❌ 只有司機可以執行此操作',
    MAX_EXTENDS_REACHED: '❌ 已達延長次數上限'
  }
};
```

---

### 4.3 modules/roomManager.js（房間管理核心）

**職責：** 房間的 CRUD 操作與狀態管理

**主要函數：**

```javascript
class RoomManager {
  constructor() {
    this.activeRooms = new Map();
  }

  /**
   * 建立新房間
   * @param {Object} options - 房間選項
   * @returns {String} roomId
   */
  createRoom(options) {
    const roomId = `${options.channelId}-${Date.now()}`;
    const roomData = {
      id: roomId,
      game: options.game,
      maxPlayers: options.maxPlayers,
      driver: options.driver,
      players: [options.driver],
      // ... 其他欄位
    };
    
    this.activeRooms.set(roomId, roomData);
    return roomId;
  }

  /**
   * 玩家加入房間
   * @param {String} roomId
   * @param {String} userId
   * @returns {Object} { success, isFull, message }
   */
  joinRoom(roomId, userId) {
    // 實作邏輯
  }

  /**
   * 玩家離開房間
   * @param {String} roomId
   * @param {String} userId
   * @returns {Object} { success, message }
   */
  leaveRoom(roomId, userId) {
    // 實作邏輯
  }

  /**
   * 延長房間時間
   * @param {String} roomId
   * @returns {Object} { success, remainingExtends }
   */
  extendRoom(roomId) {
    // 實作邏輯
  }

  /**
   * 關閉房間
   * @param {String} roomId
   * @param {String} reason
   */
  async closeRoom(roomId, reason) {
    // 實作邏輯
  }

  /**
   * 取得房間資料
   * @param {String} roomId
   * @returns {Object|null} roomData
   */
  getRoomData(roomId) {
    return this.activeRooms.get(roomId) || null;
  }
}

module.exports = new RoomManager();
```

---

### 4.4 modules/timerModule.js（計時器管理）

**職責：** 管理所有房間相關計時器

**主要函數：**

```javascript
const { TIMEOUT_CONFIG } = require('../config/constants');
const roomManager = require('./roomManager');

/**
 * 設定殭屍房計時器
 * @param {String} roomId
 */
function setZombieTimer(roomId) {
  const roomData = roomManager.getRoomData(roomId);
  if (!roomData) return;

  const timer = setTimeout(() => {
    if (roomData.players.length === 1) {
      roomManager.closeRoom(roomId, '超過 2 小時無人加入，房間已自動關閉');
    }
  }, TIMEOUT_CONFIG.ZOMBIE_ROOM_TIMEOUT);

  roomData.zombieTimer = timer;
}

/**
 * 設定自動關閉計時器（人滿後）
 * @param {String} roomId
 */
function setAutoCloseTimer(roomId) {
  const roomData = roomManager.getRoomData(roomId);
  if (!roomData) return;

  // 計算關閉時間
  const closeTime = Date.now() + TIMEOUT_CONFIG.FULL_ROOM_DURATION;
  roomData.closeAt = new Date(closeTime).toISOString();

  // 警告計時器（最後 5 分鐘）
  const warningDelay = TIMEOUT_CONFIG.FULL_ROOM_DURATION - TIMEOUT_CONFIG.WARNING_TIME;
  roomData.warningTimer = setTimeout(async () => {
    roomData.status = 'ending';
    // 更新公告為橘色
    await updateRoomEmbed(roomId);
  }, warningDelay);

  // 關閉計時器
  roomData.closeTimer = setTimeout(() => {
    roomManager.closeRoom(roomId, '⏰ 時間到，房間已自動關閉');
  }, TIMEOUT_CONFIG.FULL_ROOM_DURATION);
}

/**
 * 清除所有計時器
 * @param {String} roomId
 */
function clearAllTimers(roomId) {
  const roomData = roomManager.getRoomData(roomId);
  if (!roomData) return;

  if (roomData.zombieTimer) clearTimeout(roomData.zombieTimer);
  if (roomData.warningTimer) clearTimeout(roomData.warningTimer);
  if (roomData.closeTimer) clearTimeout(roomData.closeTimer);
}

module.exports = {
  setZombieTimer,
  setAutoCloseTimer,
  clearAllTimers
};
```

---

### 4.5 modules/embedBuilder.js（Embed 生成器）

**職責：** 生成各種狀態的 Embed 公告

**主要函數：**

```javascript
const { EmbedBuilder } = require('discord.js');
const { COLORS, ROOM_STATUS } = require('../config/constants');

/**
 * 建立招募中的 Embed
 * @param {Object} roomData
 * @returns {EmbedBuilder}
 */
function createRecruitingEmbed(roomData) {
  const embed = new EmbedBuilder()
    .setColor(COLORS.RECRUITING)
    .setTitle(`🚗 ${roomData.game} - 發車中！`)
    .setDescription(`司機 <@${roomData.driver}> 正在 **${roomData.guildName}** 揪團！`)
    .addFields(
      { name: '🎮 遊戲', value: roomData.game, inline: true },
      { name: '👥 人數', value: `${roomData.players.length}/${roomData.maxPlayers}`, inline: true },
      { name: '📊 狀態', value: '🟢 招募中', inline: true }
    );

  if (roomData.note) {
    embed.addFields({ name: '📝 備註', value: roomData.note });
  }

  if (roomData.players.length > 0) {
    embed.addFields({
      name: '👤 隊員名單',
      value: roomData.players.map(id => `<@${id}>`).join('\n')
    });
  }

  embed.setTimestamp();
  embed.setFooter({ text: `PersonaLink Bot | 來自: ${roomData.guildName}` });

  return embed;
}

/**
 * 建立已滿的 Embed
 * @param {Object} roomData
 * @returns {EmbedBuilder}
 */
function createFullEmbed(roomData) {
  const embed = new EmbedBuilder()
    .setColor(COLORS.FULL)
    .setTitle(`🚗 ${roomData.game} - 已滿！`)
    .setDescription(
      `✅ 人滿發車！所有隊員請準備！\n${roomData.players.map(id => `<@${id}>`).join(' ')}`
    )
    .addFields(
      { name: '🎮 遊戲', value: roomData.game, inline: true },
      { name: '👥 人數', value: `${roomData.players.length}/${roomData.maxPlayers}`, inline: true },
      { name: '📊 狀態', value: '🔴 已滿', inline: true }
    );

  // 顯示倒數計時
  if (roomData.closeAt) {
    const remaining = Math.floor((new Date(roomData.closeAt) - Date.now()) / 1000 / 60);
    if (remaining > 0) {
      embed.addFields({ 
        name: '⏰ 剩餘時間', 
        value: `約 ${remaining} 分鐘後自動關閉`, 
        inline: true 
      });
    }
  }

  embed.addFields({
    name: '👤 隊員名單',
    value: roomData.players.map(id => `<@${id}>`).join('\n')
  });

  embed.setTimestamp();
  embed.setFooter({ text: `PersonaLink Bot | 來自: ${roomData.guildName}` });

  return embed;
}

/**
 * 建立即將結束的 Embed
 * @param {Object} roomData
 * @returns {EmbedBuilder}
 */
function createEndingEmbed(roomData) {
  const embed = new EmbedBuilder()
    .setColor(COLORS.ENDING)
    .setTitle(`⏰ ${roomData.game} - 即將結束！`)
    .setDescription('⚠️ 房間將在 5 分鐘後自動關閉')
    .addFields(
      { name: '🎮 遊戲', value: roomData.game, inline: true },
      { name: '👥 人數', value: `${roomData.players.length}/${roomData.maxPlayers}`, inline: true },
      { name: '📊 狀態', value: '🟠 即將結束', inline: true }
    );

  embed.addFields({
    name: '👤 隊員名單',
    value: roomData.players.map(id => `<@${id}>`).join('\n')
  });

  embed.setTimestamp();
  embed.setFooter({ text: `PersonaLink Bot | 來自: ${roomData.guildName}` });

  return embed;
}

/**
 * 建立已關閉的 Embed
 * @param {Object} roomData
 * @param {String} reason
 * @returns {EmbedBuilder}
 */
function createClosedEmbed(roomData, reason) {
  const embed = new EmbedBuilder()
    .setColor(COLORS.CLOSED)
    .setTitle(`⚫ ${roomData.game} - 已結束`)
    .setDescription(reason)
    .setTimestamp();

  return embed;
}

module.exports = {
  createRecruitingEmbed,
  createFullEmbed,
  createEndingEmbed,
  createClosedEmbed
};
```

---

### 4.6 modules/fileManager.js（檔案管理）

**職責：** 讀寫 JSON 檔案（logs.json, guildSettings.json）

**主要函數：**

```javascript
const fs = require('fs');
const path = require('path');

const DATA_DIR = path.join(__dirname, '../../data');
const LOGS_FILE = path.join(DATA_DIR, 'logs.json');
const SETTINGS_FILE = path.join(DATA_DIR, 'guildSettings.json');

/**
 * 確保資料目錄存在
 */
function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

/**
 * 儲存日誌
 * @param {Object} logEntry
 */
function saveLog(logEntry) {
  try {
    ensureDataDir();
    
    let logs = [];
    if (fs.existsSync(LOGS_FILE)) {
      const data = fs.readFileSync(LOGS_FILE, 'utf8');
      logs = JSON.parse(data);
    }

    logs.push(logEntry);
    fs.writeFileSync(LOGS_FILE, JSON.stringify(logs, null, 2));
    console.log('✅ 日誌已儲存');
  } catch (error) {
    console.error('❌ 儲存日誌失敗:', error);
  }
}

/**
 * 讀取所有日誌
 * @returns {Array}
 */
function readLogs() {
  try {
    if (!fs.existsSync(LOGS_FILE)) {
      return [];
    }
    const data = fs.readFileSync(LOGS_FILE, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('❌ 讀取日誌失敗:', error);
    return [];
  }
}

/**
 * 儲存伺服器設定
 * @param {String} guildId
 * @param {Object} settings
 */
function saveGuildSettings(guildId, settings) {
  try {
    ensureDataDir();
    
    let allSettings = {};
    if (fs.existsSync(SETTINGS_FILE)) {
      const data = fs.readFileSync(SETTINGS_FILE, 'utf8');
      allSettings = JSON.parse(data);
    }

    allSettings[guildId] = {
      guildId,
      ...settings,
      updatedAt: new Date().toISOString()
    };

    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(allSettings, null, 2));
    console.log('✅ 伺服器設定已儲存');
  } catch (error) {
    console.error('❌ 儲存設定失敗:', error);
  }
}

/**
 * 讀取伺服器設定
 * @param {String} guildId
 * @returns {Object|null}
 */
function getGuildSettings(guildId) {
  try {
    if (!fs.existsSync(SETTINGS_FILE)) {
      return null;
    }
    const data = fs.readFileSync(SETTINGS_FILE, 'utf8');
    const allSettings = JSON.parse(data);
    return allSettings[guildId] || null;
  } catch (error) {
    console.error('❌ 讀取設定失敗:', error);
    return null;
  }
}

/**
 * 取得伺服器邀請連結
 * @param {String} guildId
 * @returns {String|null}
 */
function getGuildInviteUrl(guildId) {
  const settings = getGuildSettings(guildId);
  return settings?.inviteUrl || null;
}

module.exports = {
  saveLog,
  readLogs,
  saveGuildSettings,
  getGuildSettings,
  getGuildInviteUrl
};
```

---

## 5. API 參考

### 5.1 RoomManager API

```javascript
// 建立房間
const roomId = roomManager.createRoom({
  channelId: '123456',
  messageId: '789012',
  guildId: '345678',
  guildName: '測試伺服器',
  driver: 'user_id_123',
  game: '傳說對決',
  maxPlayers: 5,
  note: '限鑽石以上'
});

// 加入房間
const result = roomManager.joinRoom(roomId, 'user_id_456');
// 返回: { success: true, isFull: false, currentPlayers: 2 }

// 離開房間
const result = roomManager.leaveRoom(roomId, 'user_id_456');
// 返回: { success: true, message: '已退出房間' }

// 延長時間
const result = roomManager.extendRoom(roomId);
// 返回: { success: true, remainingExtends: 1 }

// 關閉房間
await roomManager.closeRoom(roomId, '司機取消發車');

// 取得房間資料
const roomData = roomManager.getRoomData(roomId);
```

### 5.2 Timer API

```javascript
const { setZombieTimer, setAutoCloseTimer, clearAllTimers } = require('./modules/timerModule');

// 設定殭屍房計時器
setZombieTimer(roomId);

// 設定自動關閉計時器
setAutoCloseTimer(roomId);

// 清除所有計時器
clearAllTimers(roomId);
```

### 5.3 Embed Builder API

```javascript
const { 
  createRecruitingEmbed, 
  createFullEmbed, 
  createEndingEmbed, 
  createClosedEmbed 
} = require('./modules/embedBuilder');

// 建立招募中 Embed
const embed = createRecruitingEmbed(roomData);

// 建立已滿 Embed
const embed = createFullEmbed(roomData);

// 建立即將結束 Embed
const embed = createEndingEmbed(roomData);

// 建立已關閉 Embed
const embed = createClosedEmbed(roomData, '時間到自動關閉');
```

### 5.4 File Manager API

```javascript
const { saveLog, readLogs, saveGuildSettings, getGuildSettings } = require('./modules/fileManager');

// 儲存日誌
saveLog({
  game: '傳說對決',
  driver: 'user_id',
  players: ['user1', 'user2'],
  createdAt: '2025-04-24T10:00:00Z',
  completedAt: '2025-04-24T10:30:00Z',
  duration: 1800,
  joinSpeed: 300
});

// 讀取所有日誌
const logs = readLogs();

// 儲存伺服器設定
saveGuildSettings('guild_id_123', {
  inviteUrl: 'https://discord.gg/example',
  enabled: true
});

// 取得伺服器設定
const settings = getGuildSettings('guild_id_123');
```

---

## 6. 開發規範

### 6.1 程式碼風格

**使用 ESLint + Prettier**

安裝：
```bash
npm install --save-dev eslint prettier eslint-config-prettier
```

**.eslintrc.json：**
```json
{
  "env": {
    "node": true,
    "es2021": true
  },
  "extends": ["eslint:recommended", "prettier"],
  "parserOptions": {
    "ecmaVersion": 2021
  },
  "rules": {
    "no-console": "off",
    "no-unused-vars": "warn"
  }
}
```

**.prettierrc：**
```json
{
  "semi": true,
  "trailingComma": "es5",
  "singleQuote": true,
  "printWidth": 100,
  "tabWidth": 2
}
```

### 6.2 命名規範

```javascript
// 常數：大寫蛇形命名法
const MAX_PLAYERS = 20;
const TIMEOUT_CONFIG = { ... };

// 變數/函數：小駝峰命名法
const roomData = { ... };
function createRoom() { ... }

// 類別：大駝峰命名法
class RoomManager { ... }

// 私有方法/變數：前綴 _
_internalMethod() { ... }

// 檔案名稱：小駝峰命名法
roomManager.js
embedBuilder.js
```

### 6.3 註解規範

```javascript
/**
 * 函數說明
 * @param {Type} paramName - 參數說明
 * @returns {Type} 返回值說明
 */
function functionName(paramName) {
  // 實作邏輯
}

/**
 * 複雜邏輯前加上區塊註解
 */
// 步驟 1：檢查條件
// 步驟 2：執行動作
// 步驟 3：返回結果
```

### 6.4 錯誤處理

```javascript
// 使用 try-catch 包裹所有非同步操作
async function riskyOperation() {
  try {
    const result = await someAsyncFunction();
    return { success: true, data: result };
  } catch (error) {
    console.error('操作失敗:', error);
    return { success: false, error: error.message };
  }
}

// Discord API 操作要處理失敗情況
try {
  await message.edit({ embeds: [embed] });
} catch (error) {
  console.error('更新訊息失敗:', error);
  // 不阻斷主流程
}
```

### 6.5 Git 提交規範

```bash
# 格式：<type>(<scope>): <subject>

# type 類型：
feat:     新功能
fix:      修復 Bug
docs:     文檔更新
style:    代碼格式調整
refactor: 重構
test:     測試
chore:    構建/工具變更

# 範例：
git commit -m "feat(room): 新增延長時間功能"
git commit -m "fix(timer): 修復計時器重複觸發問題"
git commit -m "docs: 更新 API 文檔"
```

---

## 7. 測試指南

### 7.1 手動測試清單

```markdown
## 基礎功能測試

- [ ] `/開車` 指令能正常觸發
- [ ] 公告正確顯示
- [ ] 按鈕可點擊
- [ ] 人數正確累加
- [ ] 人滿通知正常
- [ ] 自動關閉機制正常

## 邊界測試

- [ ] 重複點擊加入
- [ ] 滿房時點擊加入
- [ ] 非司機點延長
- [ ] 司機退出房間
- [ ] 訊息被刪除時的處理

## 跨伺服器測試

- [ ] 中央伺服器接收公告
- [ ] 公告同步更新
- [ ] 邀請連結正常
```

### 7.2 單元測試（未來）

```javascript
// tests/unit/roomManager.test.js
const roomManager = require('../../src/modules/roomManager');

describe('RoomManager', () => {
  test('createRoom 應該返回 roomId', () => {
    const roomId = roomManager.createRoom({ /* options */ });
    expect(roomId).toBeDefined();
  });

  test('joinRoom 應該正確加入玩家', () => {
    const roomId = roomManager.createRoom({ /* options */ });
    const result = roomManager.joinRoom(roomId, 'user_123');
    expect(result.success).toBe(true);
  });
});
```

### 7.3 除錯技巧

```javascript
// 開發模式下啟用詳細日誌
if (process.env.NODE_ENV === 'development') {
  console.log('[DEBUG] roomData:', JSON.stringify(roomData, null, 2));
}

// 使用 VS Code 斷點除錯
// 1. 在程式碼左側點擊設定斷點
// 2. F5 啟動除錯模式
// 3. 查看變數值與呼叫堆疊
```

---

## 8. 部署流程

### 8.1 本地測試部署

```bash
# 1. 確保所有測試通過
npm test

# 2. 啟動 Bot
npm start

# 3. 檢查日誌
tail -f logs/bot.log
```

### 8.2 部署到 Replit（雲端）

```bash
# 1. 推送到 Git
git add .
git commit -m "feat: 完成核心功能"
git push origin main

# 2. 在 Replit 匯入專案
# Import from GitHub → 選擇 repository

# 3. 設定 Secrets（.env 內容）
# 在 Replit Tools → Secrets 中設定

# 4. 點擊 Run
```

### 8.3 部署到 VPS（未來）

```bash
# 1. SSH 連線到伺服器
ssh user@your-server-ip

# 2. 克隆專案
git clone <repository-url>
cd personalink-bot

# 3. 安裝依賴
npm install --production

# 4. 設定環境變數
nano .env

# 5. 使用 PM2 管理進程
npm install -g pm2
pm2 start src/index.js --name personalink-bot
pm2 save
pm2 startup

# 6. 設定自動重啟
pm2 restart personalink-bot
```

---

## 9. 常見問題

### 9.1 Bot 無法啟動

**問題：** `Error: Incorrect login details provided.`

**解決：**
```bash
# 檢查 .env 中的 DISCORD_TOKEN 是否正確
# 重新從 Discord Developer Portal 取得 Token
```

---

### 9.2 斜線指令沒出現

**問題：** 輸入 `/` 看不到 `/開車` 指令

**解決：**
```bash
# 1. 等待 1-2 分鐘（Discord 同步需要時間）
# 2. 確認 Bot 有「Use Application Commands」權限
# 3. 檢查程式碼中的 registerCommands() 是否執行
```

---

### 9.3 按鈕點擊沒反應

**問題：** 點擊「我要排隊」按鈕無反應

**解決：**
```javascript
// 檢查 interactionCreate 事件監聽器
client.on('interactionCreate', async (interaction) => {
  console.log('收到互動:', interaction.type);
  
  if (interaction.isButton()) {
    console.log('按鈕 ID:', interaction.customId);
    // 處理邏輯
  }
});
```

---

### 9.4 計時器重啟後遺失

**問題：** Bot 重啟後所有房間計時器消失

**解決：**
```javascript
// 這是已知限制（階段 1 使用 In-Memory）
// 暫時解決方案：Bot 重啟時重建計時器
client.once('ready', () => {
  roomManager.activeRooms.forEach((room, roomId) => {
    if (room.status === 'full' && room.closeAt) {
      const remaining = new Date(room.closeAt) - Date.now();
      if (remaining > 0) {
        setAutoCloseTimer(roomId);
      }
    }
  });
});

// 長期解決方案：遷移到資料庫（階段 2）
```

---

### 9.5 跨伺服器推送失敗

**問題：** 中央伺服器沒收到公告

**解決：**
```bash
# 1. 檢查 .env 中的 CENTRAL_SERVER_ID 和 RECRUIT_CHANNEL_ID
# 2. 確認 Bot 有加入中央伺服器
# 3. 確認 Bot 對該頻道有發送訊息權限
# 4. 檢查程式碼中 ENABLE_CROSS_SERVER 是否為 true
```

---

## 10. 開發檢查清單

### 本地開發環境設定
- [ ] Node.js 18+ 已安裝
- [ ] 專案依賴已安裝（npm install）
- [ ] .env 檔案已設定
- [ ] Discord Bot Token 已填入
- [ ] Bot 已加入測試伺服器

### 程式碼撰寫
- [ ] 遵循命名規範
- [ ] 加入適當註解
- [ ] 錯誤處理完整
- [ ] 無 console.error 被忽略

### 測試
- [ ] 手動測試通過
- [ ] 邊界情況已測試
- [ ] 跨伺服器功能已測試

### 提交前
- [ ] ESLint 無錯誤
- [ ] Prettier 已格式化
- [ ] Git commit message 符合規範
- [ ] 敏感資訊未提交（.env 在 .gitignore）

---

## 附錄 A：快速參考

### Discord.js 常用 API

```javascript
// 獲取頻道
const channel = await client.channels.fetch(channelId);

// 獲取訊息
const message = await channel.messages.fetch(messageId);

// 編輯訊息
await message.edit({ embeds: [embed], components: [buttons] });

// 刪除訊息
await message.delete();

// 回應互動
await interaction.reply({ content: '訊息', ephemeral: true });
await interaction.update({ embeds: [embed] });

// 獲取伺服器成員
const guild = await client.guilds.fetch(guildId);
const member = await guild.members.fetch(userId);
```

### 常用工具函數

```javascript
// 等待一段時間
await new Promise(resolve => setTimeout(resolve, 1000));

// 格式化時間
const now = new Date().toISOString();

// 計算時間差（秒）
const duration = (Date.now() - startTime) / 1000;

// JSON 深拷貝
const copy = JSON.parse(JSON.stringify(original));
```

---

## 附錄 B：資源連結

**官方文檔：**
- [Discord.js 文檔](https://discord.js.org/)
- [Discord Developer Portal](https://discord.com/developers/applications)
- [Discord API 文檔](https://discord.com/developers/docs)

**社群資源：**
- [Discord.js Guide](https://discordjs.guide/)
- [Discord API Discord 伺服器](https://discord.gg/discord-api)

**開發工具：**
- [VS Code](https://code.visualstudio.com/)
- [Postman](https://www.postman.com/)（API 測試）
- [Discord Bot List](https://top.gg/)（上架平台）

---

**文檔版本：** 1.0  
**最後更新：** 2025-04-24  
**維護者：** PersonaLink 開發團隊

---

## 下一步行動

1. **設定本地環境** → 確保 Node.js、npm 已安裝
2. **初始化專案** → npm install、設定 .env
3. **開始開發** → 使用 Claude Code 或 Codex 協作
4. **參考架構文件** → PersonaLink_V2_Architecture.md

**準備好開始開發了嗎？** 🚀
