// ===== PersonaLink Discord Bot =====
// 跨伺服器自動發車系統

require("dotenv").config();
const {
  Client,
  GatewayIntentBits,
  SlashCommandBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  EmbedBuilder,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
  PermissionFlagsBits,
  ChannelType,
  REST,
  Routes,
} = require("discord.js");
const express = require("express");
const fs = require("fs");

// ===== 設定 =====
const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
});

const app = express();
const PORT = process.env.PORT || 3000;

// ===== 資料儲存 =====
let activeRooms = new Map(); // roomId -> roomData
let pendingRooms = new Map(); // userId -> {gameName, maxPlayers, rules}

// ===== 持久化設定（每個伺服器的廣播頻道） =====
const SETTINGS_FILE = "settings.json";
let settings = { guilds: {} }; // { guilds: { [guildId]: { broadcastChannelId } } }

function loadSettings() {
  try {
    if (fs.existsSync(SETTINGS_FILE)) {
      settings = JSON.parse(fs.readFileSync(SETTINGS_FILE, "utf8"));
      if (!settings.guilds) settings.guilds = {};
    }
  } catch (e) {
    console.error("❌ settings.json 讀取失敗:", e.message);
  }
}

function saveSettings() {
  try {
    fs.writeFileSync(SETTINGS_FILE, JSON.stringify(settings, null, 2));
  } catch (e) {
    console.error("❌ settings.json 儲存失敗:", e.message);
  }
}

loadSettings();

// ===== 自動補全建議清單 =====
const GAME_SUGGESTIONS = [
  "傳說對決",
  "英雄聯盟",
  "激鬥峽谷",
  "Valorant",
  "特戰英豪",
  "Apex Legends",
  "PUBG",
  "絕地求生",
  "CS2",
  "Overwatch 2",
  "鬥陣特攻 2",
  "爐石戰記",
  "暗黑破壞神 4",
  "暗黑破壞神:不朽",
  "原神",
  "崩壞:星穹鐵道",
  "鳴潮",
  "第五人格",
  "決勝時刻",
  "Minecraft",
  "瑪利歐賽車",
  "任天堂明星大亂鬥",
];

const RULE_SUGGESTIONS = [
  "限有麥",
  "不限段位",
  "限白金以上",
  "限鑽石以上",
  "限大師以上",
  "新手友善",
  "純娛樂",
  "認真上分",
  "限女生",
  "限男生",
  "禁掛機",
  "禁辱罵",
  "歡迎新手",
  "排位賽",
  "歡樂場",
];

// ===== Express 伺服器 (保持 Replit 運行) =====
app.get("/", (req, res) => {
  res.send("✅ PersonaLink Bot is running!");
});

app.listen(PORT, () => {
  console.log(`🚀 Keep-alive server running on port ${PORT}`);
});

// ===== Bot 啟動 + 註冊指令 =====
client.once("ready", async () => {
  console.log(`✅ Bot 已上線: ${client.user.tag}`);

  const commands = [
    new SlashCommandBuilder()
      .setName("開車")
      .setDescription("建立遊戲房間，跨伺服器揪團！")
      .addStringOption((o) =>
        o
          .setName("遊戲")
          .setDescription("遊戲名稱 (可從建議選擇或自行輸入)")
          .setRequired(false)
          .setAutocomplete(true),
      )
      .addIntegerOption((o) =>
        o
          .setName("人數")
          .setDescription("需要多少人 (預設: 5)")
          .setRequired(false)
          .setMinValue(2)
          .setMaxValue(20),
      )
      .addStringOption((o) =>
        o
          .setName("規定")
          .setDescription("房間規定 (可從建議選擇或自行輸入)")
          .setRequired(false)
          .setAutocomplete(true),
      ),

    new SlashCommandBuilder()
      .setName("設定發車頻道")
      .setDescription("設定本伺服器接收跨伺服器房間的頻道（管理員）")
      .setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild)
      .addChannelOption((o) =>
        o
          .setName("頻道")
          .setDescription("接收跨伺服器發車公告的文字頻道")
          .addChannelTypes(ChannelType.GuildText)
          .setRequired(true),
      ),

    new SlashCommandBuilder()
      .setName("停用跨伺服器")
      .setDescription("停止本伺服器接收跨伺服器房間（管理員）")
      .setDefaultMemberPermissions(PermissionFlagsBits.ManageGuild),

    new SlashCommandBuilder()
      .setName("跨伺服器狀態")
      .setDescription("查看本伺服器目前的跨伺服器設定"),
  ].map((c) => c.toJSON());

  const rest = new REST({ version: "10" }).setToken(process.env.DISCORD_TOKEN);

  try {
    console.log("🔄 開始註冊斜線指令...");
    await rest.put(Routes.applicationCommands(client.user.id), {
      body: commands,
    });
    console.log("✅ 斜線指令註冊成功！");
  } catch (error) {
    console.error("❌ 指令註冊失敗:", error);
  }
});

// ===== UI Helpers =====
function formatPlayerLine(player, driverId) {
  const crown = player.id === driverId ? "👑" : "▫️";
  const hasInfo =
    (player.gameId && player.gameId !== "未填寫") ||
    (player.rank && player.rank !== "未填寫");
  const info = hasInfo ? ` — \`${player.gameId}\` · \`${player.rank}\`` : "";
  return `${crown} <@${player.id}> (${player.username})${info}`;
}

function buildEmbed(roomData, isFull = false) {
  const playerLines =
    roomData.players
      .map((p) => formatPlayerLine(p, roomData.driver))
      .join("\n") || "尚無隊員";

  const embed = new EmbedBuilder()
    .setColor(isFull ? "#ff0000" : "#00ff00")
    .setTitle(`🚗 ${roomData.game} - ${isFull ? "已滿！" : "發車中！"}`)
    .setDescription(
      isFull
        ? `✅ 人滿發車！所有隊員請準備！\n${roomData.players.map((p) => `<@${p.id}>`).join(" ")}`
        : `司機 <@${roomData.driver}> 正在揪團！`,
    )
    .addFields(
      {
        name: "目前人數",
        value: `${roomData.players.length}/${roomData.maxPlayers}`,
        inline: true,
      },
      { name: "狀態", value: isFull ? "🔴 已滿" : "🟢 招募中", inline: true },
      { name: "📋 規定", value: roomData.rules || "無", inline: false },
      { name: "隊員名單", value: playerLines },
    )
    .setTimestamp()
    .setFooter({
      text: `來自 ${roomData.originGuildName} · PersonaLink`,
    });

  return embed;
}

function buildButtons(roomId, isFull) {
  return [
    new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId(`join_${roomId}`)
        .setLabel("🎮 我要排隊")
        .setStyle(ButtonStyle.Success)
        .setDisabled(isFull),
      new ButtonBuilder()
        .setCustomId(`leave_${roomId}`)
        .setLabel("❌ 取消排隊")
        .setStyle(ButtonStyle.Danger),
      new ButtonBuilder()
        .setCustomId(`view_${roomId}`)
        .setLabel("📋 查看隊員")
        .setStyle(ButtonStyle.Secondary),
    ),
  ];
}

function buildPlayerInfoModal(customId, title) {
  const modal = new ModalBuilder().setCustomId(customId).setTitle(title);
  modal.addComponents(
    new ActionRowBuilder().addComponents(
      new TextInputBuilder()
        .setCustomId("gameId")
        .setLabel("遊戲 ID / 暱稱")
        .setPlaceholder("例如: 小明#1234")
        .setStyle(TextInputStyle.Short)
        .setRequired(false)
        .setMaxLength(50),
    ),
    new ActionRowBuilder().addComponents(
      new TextInputBuilder()
        .setCustomId("rank")
        .setLabel("段位 / 等級")
        .setPlaceholder("例如: 鑽石 II")
        .setStyle(TextInputStyle.Short)
        .setRequired(false)
        .setMaxLength(50),
    ),
  );
  return modal;
}

// ===== 跨伺服器廣播 =====
function getBroadcastTargets(excludeGuildId) {
  const targets = [];
  for (const [gid, conf] of Object.entries(settings.guilds)) {
    if (gid === excludeGuildId) continue;
    if (conf && conf.broadcastChannelId) {
      targets.push({ guildId: gid, channelId: conf.broadcastChannelId });
    }
  }
  return targets;
}

async function broadcastNewRoom(roomData) {
  const embed = buildEmbed(roomData, false);
  const components = buildButtons(roomData.id, false);
  const targets = getBroadcastTargets(roomData.originGuildId);

  await Promise.all(
    targets.map(async (target) => {
      try {
        const guild = await client.guilds.fetch(target.guildId);
        const channel = await guild.channels.fetch(target.channelId);
        if (!channel || !channel.isTextBased()) return;
        const msg = await channel.send({ embeds: [embed], components });
        roomData.messages.push({
          guildId: target.guildId,
          channelId: target.channelId,
          messageId: msg.id,
        });
      } catch (e) {
        console.error(`⚠️ 廣播至 guild ${target.guildId} 失敗:`, e.message);
      }
    }),
  );
}

async function updateAllRoomMessages(roomData, isFull) {
  const embed = buildEmbed(roomData, isFull);
  const components = buildButtons(roomData.id, isFull);

  await Promise.all(
    roomData.messages.map(async (ref) => {
      try {
        const guild = await client.guilds.fetch(ref.guildId);
        const channel = await guild.channels.fetch(ref.channelId);
        const msg = await channel.messages.fetch(ref.messageId);
        await msg.edit({ embeds: [embed], components });
      } catch (e) {
        console.error(
          `⚠️ 更新訊息失敗 ${ref.guildId}/${ref.channelId}/${ref.messageId}:`,
          e.message,
        );
      }
    }),
  );
}

async function closeAllRoomMessages(roomData, content) {
  await Promise.all(
    roomData.messages.map(async (ref) => {
      try {
        const guild = await client.guilds.fetch(ref.guildId);
        const channel = await guild.channels.fetch(ref.channelId);
        const msg = await channel.messages.fetch(ref.messageId);
        await msg.edit({ content, embeds: [], components: [] });
      } catch (e) {
        console.error(`⚠️ 關閉訊息失敗:`, e.message);
      }
    }),
  );
}

// ===== 自動補全處理 =====
client.on("interactionCreate", async (interaction) => {
  if (!interaction.isAutocomplete()) return;

  const focused = interaction.options.getFocused(true);
  const input = (focused.value || "").toLowerCase();

  let pool = [];
  if (focused.name === "遊戲") pool = GAME_SUGGESTIONS;
  else if (focused.name === "規定") pool = RULE_SUGGESTIONS;

  const filtered = (
    input ? pool.filter((item) => item.toLowerCase().includes(input)) : pool
  ).slice(0, 25);

  await interaction.respond(
    filtered.map((item) => ({ name: item, value: item })),
  );
});

// ===== 斜線指令處理 =====
client.on("interactionCreate", async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  // === /開車 ===
  if (interaction.commandName === "開車") {
    if (!interaction.guildId) {
      return interaction.reply({
        content: "❌ 請在伺服器頻道內使用此指令",
        ephemeral: true,
      });
    }
    const gameName = interaction.options.getString("遊戲") || "未指定";
    const maxPlayers = interaction.options.getInteger("人數") || 5;
    const rules = interaction.options.getString("規定") || "無";

    pendingRooms.set(interaction.user.id, { gameName, maxPlayers, rules });
    return interaction.showModal(
      buildPlayerInfoModal("create_room_modal", "🚗 開車前 - 填寫你的資料"),
    );
  }

  // === /設定發車頻道 ===
  if (interaction.commandName === "設定發車頻道") {
    if (!interaction.guildId) {
      return interaction.reply({
        content: "❌ 請在伺服器內使用此指令",
        ephemeral: true,
      });
    }
    const channel = interaction.options.getChannel("頻道");
    if (!settings.guilds[interaction.guildId]) {
      settings.guilds[interaction.guildId] = {};
    }
    settings.guilds[interaction.guildId].broadcastChannelId = channel.id;
    saveSettings();

    return interaction.reply({
      content: `✅ 跨伺服器發車已開啟！房間將會推送到 <#${channel.id}>`,
      ephemeral: true,
    });
  }

  // === /停用跨伺服器 ===
  if (interaction.commandName === "停用跨伺服器") {
    if (!interaction.guildId) {
      return interaction.reply({
        content: "❌ 請在伺服器內使用此指令",
        ephemeral: true,
      });
    }
    if (settings.guilds[interaction.guildId]) {
      delete settings.guilds[interaction.guildId].broadcastChannelId;
      saveSettings();
    }
    return interaction.reply({
      content: "🛑 已停用跨伺服器功能，本伺服器不再接收外部房間",
      ephemeral: true,
    });
  }

  // === /跨伺服器狀態 ===
  if (interaction.commandName === "跨伺服器狀態") {
    const conf = settings.guilds[interaction.guildId];
    const enabledGuilds = Object.entries(settings.guilds).filter(
      ([, c]) => c && c.broadcastChannelId,
    ).length;

    if (conf && conf.broadcastChannelId) {
      return interaction.reply({
        content:
          `🟢 **本伺服器**：已開啟，發車頻道 <#${conf.broadcastChannelId}>\n` +
          `🌐 **目前共 ${enabledGuilds} 個伺服器**啟用跨伺服器功能`,
        ephemeral: true,
      });
    } else {
      return interaction.reply({
        content:
          `⚪ **本伺服器**：未開啟（用 \`/設定發車頻道\` 開啟）\n` +
          `🌐 目前共 ${enabledGuilds} 個伺服器啟用跨伺服器功能`,
        ephemeral: true,
      });
    }
  }
});

// ===== Modal 提交處理 =====
client.on("interactionCreate", async (interaction) => {
  if (!interaction.isModalSubmit()) return;

  // === 開車 Modal ===
  if (interaction.customId === "create_room_modal") {
    const pending = pendingRooms.get(interaction.user.id);
    if (!pending) {
      return interaction.reply({
        content: "❌ 開車資料已過期，請重新使用 `/開車`",
        ephemeral: true,
      });
    }
    pendingRooms.delete(interaction.user.id);

    const gameId =
      interaction.fields.getTextInputValue("gameId").trim() || "未填寫";
    const rank =
      interaction.fields.getTextInputValue("rank").trim() || "未填寫";
    const driver = interaction.user;

    const originGuild = interaction.guild;
    const roomId = `${interaction.channelId}-${Date.now()}`;
    const roomData = {
      id: roomId,
      game: pending.gameName,
      maxPlayers: pending.maxPlayers,
      rules: pending.rules,
      driver: driver.id,
      players: [
        { id: driver.id, username: driver.username, gameId, rank },
      ],
      originGuildId: originGuild.id,
      originGuildName: originGuild.name,
      originChannelId: interaction.channelId,
      messages: [],
      createdAt: new Date().toISOString(),
    };

    activeRooms.set(roomId, roomData);

    // 1) 在開車的原頻道回覆
    await interaction.reply({
      embeds: [buildEmbed(roomData, false)],
      components: buildButtons(roomId, false),
    });
    const originMsg = await interaction.fetchReply();
    roomData.messages.push({
      guildId: originGuild.id,
      channelId: interaction.channelId,
      messageId: originMsg.id,
    });

    // 2) 廣播至其他啟用跨伺服器的伺服器
    const targetCount = getBroadcastTargets(originGuild.id).length;
    await broadcastNewRoom(roomData);
    if (targetCount > 0) {
      await interaction.followUp({
        content: `🌐 已同步發送至 **${roomData.messages.length - 1}** 個其他伺服器`,
        ephemeral: true,
      });
    }
    return;
  }

  // === 排隊 Modal ===
  if (interaction.customId.startsWith("join_modal_")) {
    const roomId = interaction.customId.slice("join_modal_".length);
    const roomData = activeRooms.get(roomId);

    if (!roomData) {
      return interaction.reply({
        content: "❌ 房間已結束或不存在！",
        ephemeral: true,
      });
    }

    const userId = interaction.user.id;
    if (roomData.players.some((p) => p.id === userId)) {
      return interaction.reply({
        content: "⚠️ 你已經在隊伍中了！",
        ephemeral: true,
      });
    }
    if (roomData.players.length >= roomData.maxPlayers) {
      return interaction.reply({ content: "❌ 房間已滿！", ephemeral: true });
    }

    const gameId =
      interaction.fields.getTextInputValue("gameId").trim() || "未填寫";
    const rank =
      interaction.fields.getTextInputValue("rank").trim() || "未填寫";

    roomData.players.push({
      id: userId,
      username: interaction.user.username,
      gameId,
      rank,
    });

    const isFull = roomData.players.length >= roomData.maxPlayers;

    await interaction.reply({
      content: `✅ 已加入 **${roomData.game}** 隊伍！`,
      ephemeral: true,
    });

    await updateAllRoomMessages(roomData, isFull);

    if (isFull) {
      saveLog(roomData);
      setTimeout(() => activeRooms.delete(roomId), 5000);
    }
    return;
  }
});

// ===== 按鈕互動處理 =====
client.on("interactionCreate", async (interaction) => {
  if (!interaction.isButton()) return;

  const idx = interaction.customId.indexOf("_");
  const action = interaction.customId.slice(0, idx);
  const roomId = interaction.customId.slice(idx + 1);
  const roomData = activeRooms.get(roomId);

  if (!roomData) {
    return interaction.reply({
      content: "❌ 房間已結束或不存在！",
      ephemeral: true,
    });
  }

  const userId = interaction.user.id;

  // === 加入排隊 → 跳出 Modal ===
  if (action === "join") {
    if (roomData.players.some((p) => p.id === userId)) {
      return interaction.reply({
        content: "⚠️ 你已經在隊伍中了！",
        ephemeral: true,
      });
    }
    if (roomData.players.length >= roomData.maxPlayers) {
      return interaction.reply({ content: "❌ 房間已滿！", ephemeral: true });
    }
    return interaction.showModal(
      buildPlayerInfoModal(`join_modal_${roomId}`, "🎮 加入隊伍 - 填寫資料"),
    );
  }

  // === 取消排隊 ===
  if (action === "leave") {
    if (!roomData.players.some((p) => p.id === userId)) {
      return interaction.reply({
        content: "⚠️ 你不在隊伍中！",
        ephemeral: true,
      });
    }

    if (userId === roomData.driver) {
      activeRooms.delete(roomId);
      await interaction.reply({
        content: "🛑 已取消發車，所有伺服器房間將關閉",
        ephemeral: true,
      });
      await closeAllRoomMessages(
        roomData,
        "🛑 司機已取消發車，房間關閉！",
      );
      return;
    }

    roomData.players = roomData.players.filter((p) => p.id !== userId);
    await interaction.reply({
      content: `已退出 **${roomData.game}** 隊伍`,
      ephemeral: true,
    });
    await updateAllRoomMessages(roomData, false);
    return;
  }

  // === 查看隊員（悄悄話） ===
  if (action === "view") {
    const lines = roomData.players
      .map((p) => {
        const role = p.id === roomData.driver ? "👑 司機" : "▫️ 隊員";
        return `${role} **${p.username}** <@${p.id}>\n　遊戲ID: \`${p.gameId}\`　段位: \`${p.rank}\``;
      })
      .join("\n\n");

    return interaction.reply({
      content:
        `**🎮 ${roomData.game} 隊員資料 (${roomData.players.length}/${roomData.maxPlayers})**\n` +
        `🌐 來自：${roomData.originGuildName}\n\n${lines}`,
      ephemeral: true,
    });
  }
});

// ===== 資料記錄 =====
function saveLog(roomData) {
  try {
    let logs = [];
    if (fs.existsSync("logs.json")) {
      const data = fs.readFileSync("logs.json", "utf8");
      logs = JSON.parse(data);
    }

    logs.push({
      game: roomData.game,
      rules: roomData.rules,
      players: roomData.players,
      originGuildName: roomData.originGuildName,
      originGuildId: roomData.originGuildId,
      broadcastCount: roomData.messages.length,
      createdAt: roomData.createdAt,
      completedAt: new Date().toISOString(),
    });

    fs.writeFileSync("logs.json", JSON.stringify(logs, null, 2));
    console.log("✅ 發車記錄已儲存");
  } catch (error) {
    console.error("❌ 記錄儲存失敗:", error);
  }
}

// ===== Bot 登入 =====
client.login(process.env.DISCORD_TOKEN);
