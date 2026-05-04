---
task_id: task-003
status: ready
assigned_to: claude_code
created: 2026-05-04
depends_on: [task-001, task-002]
estimated_lines: 260
---

# Task: Add Admin Command Interface

## Objective

Add Discord slash commands that allow administrators to inspect and manage Discord Bot Guard moderation behavior from inside a guild.

## Context

The spec requires automated management commands. These commands should expose practical controls for the message filtering system from task-002 without requiring manual JSON edits.

## Allowed Files

- `discord-bot/index.js`
- `discord-bot/settings.json`
- `discord-bot/logs.json`
- `.dev-flow/tasks/task-003.md`

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

- Register slash commands using Discord.js v14 REST APIs.
- Add admin-only commands for:
  - viewing current guard settings
  - enabling or disabling spam filtering per guild
  - setting moderation log channel
  - updating basic spam thresholds
- Require `ManageGuild` or equivalent administrator permission for configuration commands.
- Reply ephemerally to administrative configuration actions.
- Persist guild settings to `settings.json`.
- Record configuration changes to `logs.json`.
- Keep commands guild-safe and avoid exposing secrets.

## Acceptance Criteria

- [ ] Slash command registration completes during bot startup when valid credentials are provided.
- [ ] Non-admin users cannot change guard settings.
- [ ] Admin users can view current settings.
- [ ] Admin users can enable or disable filtering.
- [ ] Admin users can set a moderation log channel.
- [ ] Admin users can update supported thresholds.
- [ ] `node --check discord-bot/index.js` passes.

## Validation Commands

```bash
node --check discord-bot/index.js
```

Manual validation:

```bash
cd discord-bot
npm start
```

Then test slash commands in a private test guild.

## Implementation Notes

Keep command names ASCII and descriptive, such as `/guard-status`, `/guard-enable`, `/guard-disable`, `/guard-log-channel`, and `/guard-threshold`. If command registration requires an application ID, derive it from `client.user.id` after `ready` as the existing legacy bot attempted to do.

## Review Notes

To be completed by Codex.
