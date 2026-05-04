---
task_id: task-001
status: ready
assigned_to: claude_code
created: 2026-05-04
depends_on: []
estimated_lines: 180
---

# Task: Establish Guard Bot Runtime Baseline

## Objective

Replace the existing legacy team-up bot entrypoint with a runnable Discord Bot Guard baseline that connects to Discord, validates required configuration, registers core Discord.js event handlers, and provides a stable foundation for moderation, admin commands, and logging.

## Context

The updated spec requires a Discord.js v14 bot for server management and security protection. The current `discord-bot/index.js` appears to be an unrelated cross-server team-up bot and contains mojibake plus JavaScript syntax errors. Before moderation features can be added, the runtime must be simplified into a working guard bot skeleton.

## Allowed Files

- `discord-bot/index.js`
- `discord-bot/settings.json`
- `discord-bot/logs.json`
- `.dev-flow/tasks/task-001.md`

## Forbidden Files

- `.ai-harness/policies/`
- `.ai-harness/templates/`
- `.ai-harness/schemas/`
- `ai-harness-source`
- `.env`
- `*.key`
- `*.pem`
- `.github/workflows/`
- root `package.json`
- lockfiles
- `CLAUDE.md`

## Requirements

- Use Discord.js v14 APIs already available in `discord-bot/package.json`.
- Keep the Express keep-alive endpoint only if it remains minimal and does not hide startup failures.
- Validate `DISCORD_TOKEN` before calling `client.login`.
- Create a Discord client with intents needed for guilds, guild messages, message content, and member moderation workflows.
- Add `ready`, `error`, and `warn` handlers with clear console output.
- Add a placeholder `messageCreate` guard flow that ignores bot messages and DMs, but does not yet enforce filtering.
- Preserve JSON files as valid JSON.
- Do not add new dependencies in this task.

## Acceptance Criteria

- [ ] `node --check discord-bot/index.js` passes.
- [ ] Starting the bot without `DISCORD_TOKEN` fails fast with a clear message and does not attempt Discord login.
- [ ] The bot can log a successful `ready` event when valid Discord credentials are provided.
- [ ] `discord-bot/settings.json` and `discord-bot/logs.json` remain valid JSON.
- [ ] No Harness governance assets are modified.

## Validation Commands

```bash
node --check discord-bot/index.js
```

Manual validation with credentials:

```bash
cd discord-bot
npm start
```

## Implementation Notes

Prefer a small, readable CommonJS implementation because the existing bot package uses `index.js` and does not define ESM mode. Do not implement spam filtering, slash commands, or SQLite persistence yet; this task is the runtime baseline only.

## Review Notes

To be completed by Codex.
