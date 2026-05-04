# Handoff To Claude Code

## Execute First

Task: `.dev-flow/tasks/task-001.md`
Context: `.dev-flow/tasks/task-001.context.md`

## Objective

Establish a clean Discord Bot Guard runtime baseline by replacing the current legacy team-up bot entrypoint with a minimal Discord.js v14 guard bot that validates configuration, connects to Discord, and exposes stable event hooks for later moderation features.

## Required Scope

Allowed implementation files:

- `discord-bot/index.js`
- `discord-bot/settings.json`
- `discord-bot/logs.json`

Task record file:

- `.dev-flow/tasks/task-001.md`

Do not modify:

- `.ai-harness/policies/`
- `.ai-harness/templates/`
- `.ai-harness/schemas/`
- `ai-harness-source`
- `.env`
- secrets or key files
- `.github/workflows/`
- root `package.json`
- lockfiles
- `CLAUDE.md`

## Acceptance Criteria

- `node --check discord-bot/index.js` passes.
- Missing `DISCORD_TOKEN` fails fast with a clear startup error before login.
- Valid credentials allow the bot to reach the Discord `ready` event.
- Bot messages and DMs are ignored by the placeholder message handler.
- `settings.json` and `logs.json` remain valid JSON.

## Validation Command

```bash
node --check discord-bot/index.js
```

Record any manual runtime validation separately if valid Discord credentials are available.
