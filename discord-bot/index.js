// ===== PersonaLink Discord Bot =====
// 快速自動發車系統

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
let activeRooms = new Map(); // 房間資料
let pendingRooms = new Map(); // 司機開車前暫存的房間參數 (userId -> {game, maxPlayers, rules})

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
      .setDescription("建立遊戲房間，開始揪團！")
      .addStringOption((option) =>
        option
          .setName("遊戲")
          .setDescription("遊戲名稱 (可從建議選擇或自行輸入)")
          .setRequired(false)
          .setAutocomplete(true),
      )
      .addIntegerOption((option) =>
        option
          .setName("人數")
          .setDescription("需要多少人 (預設: 5)")
          .setRequired(false)
          .setMinValue(2)
          .setMaxValue(20),
      )
      .addStringOption((option) =>
        option
          .setName("規定")
          .setDescription("房間規定 (可從建議選擇或自行輸入)")
          .setRequired(false)
          .setAutocomplete(true),
      ),
  ].map((command) => command.toJSON());

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

  return new EmbedBuilder()
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
    .setFooter({ text: "PersonaLink Bot" });
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

// ===== /開車 指令處理 =====
client.on("interactionCreate", async (interaction) => {
  if (!interaction.isChatInputCommand()) return;
  if (interaction.commandName !== "開車") return;

  const gameName = interaction.options.getString("遊戲") || "未指定";
  const maxPlayers = interaction.options.getInteger("人數") || 5;
  const rules = interaction.options.getString("規定") || "無";

  // 暫存房間參數，待 Modal 提交時取用
  pendingRooms.set(interaction.user.id, { gameName, maxPlayers, rules });

  await interaction.showModal(
    buildPlayerInfoModal("create_room_modal", "🚗 開車前 - 填寫你的資料"),
  );
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

    const roomId = `${interaction.channelId}-${Date.now()}`;
    const roomData = {
      id: roomId,
      game: pending.gameName,
      maxPlayers: pending.maxPlayers,
      rules: pending.rules,
      driver: driver.id,
      players: [
        {
          id: driver.id,
          username: driver.username,
          gameId,
          rank,
        },
      ],
      channelId: interaction.channelId,
      createdAt: new Date().toISOString(),
    };

    activeRooms.set(roomId, roomData);

    await interaction.reply({
      embeds: [buildEmbed(roomData, false)],
      components: buildButtons(roomId, false),
    });

    const message = await interaction.fetchReply();
    roomData.messageId = message.id;
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

    // 更新原本的房間公告訊息
    if (interaction.message) {
      await interaction.message.edit({
        embeds: [buildEmbed(roomData, isFull)],
        components: buildButtons(roomId, isFull),
      });
    }

    await interaction.reply({
      content: `✅ 已加入 **${roomData.game}** 隊伍！`,
      ephemeral: true,
    });

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

  // === 加入排隊 → 彈出 Modal ===
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
      return interaction.update({
        content: "🛑 司機已取消發車，房間關閉！",
        embeds: [],
        components: [],
      });
    }

    roomData.players = roomData.players.filter((p) => p.id !== userId);
    return interaction.update({
      embeds: [buildEmbed(roomData, false)],
      components: buildButtons(roomId, false),
    });
  }

  // === 查看隊員（悄悄話） ===
  if (action === "view") {
    const lines = roomData.players
      .map((p) => {
        const crown = p.id === roomData.driver ? "👑 司機" : "▫️ 隊員";
        return `${crown} **${p.username}** <@${p.id}>\n　遊戲ID: \`${p.gameId}\`　段位: \`${p.rank}\``;
      })
      .join("\n\n");

    return interaction.reply({
      content: `**🎮 ${roomData.game} 隊員資料 (${roomData.players.length}/${roomData.maxPlayers})**\n\n${lines}`,
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
