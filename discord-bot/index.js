// ===== PersonaLink Discord Bot =====
// 快速自動發車系統 - 48小時 MVP 版本

require("dotenv").config();
const {
  Client,
  GatewayIntentBits,
  SlashCommandBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  EmbedBuilder,
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
let activeRooms = new Map(); // 儲存活躍房間資料

// ===== Express 伺服器 (保持 Replit 運行) =====
app.get("/", (req, res) => {
  res.send("✅ PersonaLink Bot is running!");
});

app.listen(PORT, () => {
  console.log(`🚀 Keep-alive server running on port ${PORT}`);
});

// ===== Bot 啟動 =====
client.once("ready", async () => {
  console.log(`✅ Bot 已上線: ${client.user.tag}`);

  // 註冊斜線指令
  const commands = [
    new SlashCommandBuilder()
      .setName("開車")
      .setDescription("建立遊戲房間，開始揪團！")
      .addStringOption((option) =>
        option
          .setName("遊戲")
          .setDescription("遊戲名稱 (例如: 傳說對決、英雄聯盟)")
          .setRequired(true),
      )
      .addIntegerOption((option) =>
        option
          .setName("人數")
          .setDescription("需要多少人 (預設: 5)")
          .setRequired(false)
          .setMinValue(2)
          .setMaxValue(20),
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

// ===== /開車 指令處理 =====
client.on("interactionCreate", async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === "開車") {
    const gameName = interaction.options.getString("遊戲");
    const maxPlayers = interaction.options.getInteger("人數") || 5;
    const driver = interaction.user;

    // 建立房間資料
    const roomId = `${interaction.channelId}-${Date.now()}`;
    const roomData = {
      id: roomId,
      game: gameName,
      maxPlayers: maxPlayers,
      driver: driver.id,
      players: [driver.id],
      channelId: interaction.channelId,
      createdAt: new Date().toISOString(),
    };

    activeRooms.set(roomId, roomData);

    // 建立嵌入式公告
    const embed = new EmbedBuilder()
      .setColor("#00ff00")
      .setTitle(`🚗 ${gameName} - 發車中！`)
      .setDescription(`司機 <@${driver.id}> 正在揪團！`)
      .addFields(
        {
          name: "目前人數",
          value: `${roomData.players.length}/${maxPlayers}`,
          inline: true,
        },
        { name: "狀態", value: "🟢 招募中", inline: true },
      )
      .setTimestamp()
      .setFooter({ text: "PersonaLink Bot" });

    // 建立按鈕
    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId(`join_${roomId}`)
        .setLabel("🎮 我要排隊")
        .setStyle(ButtonStyle.Success),
      new ButtonBuilder()
        .setCustomId(`leave_${roomId}`)
        .setLabel("❌ 取消排隊")
        .setStyle(ButtonStyle.Danger),
    );

    await interaction.reply({ embeds: [embed], components: [row] });

    // 儲存訊息 ID 用於後續更新
    const message = await interaction.fetchReply();
    roomData.messageId = message.id;
  }
});

// ===== 按鈕互動處理 =====
client.on("interactionCreate", async (interaction) => {
  if (!interaction.isButton()) return;

  const [action, roomId] = interaction.customId.split("_");
  const roomData = activeRooms.get(roomId);

  if (!roomData) {
    return interaction.reply({
      content: "❌ 房間已結束或不存在！",
      ephemeral: true,
    });
  }

  const userId = interaction.user.id;

  // === 加入排隊 ===
  if (action === "join") {
    // 檢查是否已在隊伍中
    if (roomData.players.includes(userId)) {
      return interaction.reply({
        content: "⚠️ 你已經在隊伍中了！",
        ephemeral: true,
      });
    }

    // 檢查是否已滿
    if (roomData.players.length >= roomData.maxPlayers) {
      return interaction.reply({ content: "❌ 房間已滿！", ephemeral: true });
    }

    // 加入隊伍
    roomData.players.push(userId);

    // 更新公告
    const isFull = roomData.players.length >= roomData.maxPlayers;
    const embed = new EmbedBuilder()
      .setColor(isFull ? "#ff0000" : "#00ff00")
      .setTitle(`🚗 ${roomData.game} - ${isFull ? "已滿！" : "發車中！"}`)
      .setDescription(
        isFull
          ? `✅ 人滿發車！所有隊員請準備！\n${roomData.players.map((id) => `<@${id}>`).join(" ")}`
          : `司機 <@${roomData.driver}> 正在揪團！`,
      )
      .addFields(
        {
          name: "目前人數",
          value: `${roomData.players.length}/${roomData.maxPlayers}`,
          inline: true,
        },
        { name: "狀態", value: isFull ? "🔴 已滿" : "🟢 招募中", inline: true },
        {
          name: "隊員名單",
          value: roomData.players.map((id) => `<@${id}>`).join("\n"),
        },
      )
      .setTimestamp()
      .setFooter({ text: "PersonaLink Bot" });

    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId(`join_${roomId}`)
        .setLabel("🎮 我要排隊")
        .setStyle(ButtonStyle.Success)
        .setDisabled(isFull),
      new ButtonBuilder()
        .setCustomId(`leave_${roomId}`)
        .setLabel("❌ 取消排隊")
        .setStyle(ButtonStyle.Danger),
    );

    await interaction.update({ embeds: [embed], components: [row] });

    // 如果人滿，記錄到 logs.json
    if (isFull) {
      saveLog(roomData);
      // 可選：5 秒後自動清理房間
      setTimeout(() => activeRooms.delete(roomId), 5000);
    }
  }

  // === 取消排隊 ===
  if (action === "leave") {
    if (!roomData.players.includes(userId)) {
      return interaction.reply({
        content: "⚠️ 你不在隊伍中！",
        ephemeral: true,
      });
    }

    // 如果是司機要離開
    if (userId === roomData.driver) {
      activeRooms.delete(roomId);
      return interaction.update({
        content: "🛑 司機已取消發車，房間關閉！",
        embeds: [],
        components: [],
      });
    }

    // 移除玩家
    roomData.players = roomData.players.filter((id) => id !== userId);

    // 更新公告
    const embed = new EmbedBuilder()
      .setColor("#00ff00")
      .setTitle(`🚗 ${roomData.game} - 發車中！`)
      .setDescription(`司機 <@${roomData.driver}> 正在揪團！`)
      .addFields(
        {
          name: "目前人數",
          value: `${roomData.players.length}/${roomData.maxPlayers}`,
          inline: true,
        },
        { name: "狀態", value: "🟢 招募中", inline: true },
        {
          name: "隊員名單",
          value:
            roomData.players.map((id) => `<@${id}>`).join("\n") || "尚無隊員",
        },
      )
      .setTimestamp()
      .setFooter({ text: "PersonaLink Bot" });

    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId(`join_${roomId}`)
        .setLabel("🎮 我要排隊")
        .setStyle(ButtonStyle.Success),
      new ButtonBuilder()
        .setCustomId(`leave_${roomId}`)
        .setLabel("❌ 取消排隊")
        .setStyle(ButtonStyle.Danger),
    );

    await interaction.update({ embeds: [embed], components: [row] });
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
