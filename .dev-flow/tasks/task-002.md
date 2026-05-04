---
task_id: task-002
status: ready
assigned_to: claude_code
created: 2026-05-04
depends_on: [task-001]
estimated_lines: 220
---

# Task: Implement Message Spam Filtering

## Objective

Add automatic spam-message detection and enforcement to Discord Bot Guard so guild messages can be evaluated, logged, and handled according to configurable thresholds.

## Context

The spec requires automatic detection and handling of spam messages. This task builds on the baseline `messageCreate` flow from task-001 and should keep the first moderation rules simple, testable, and configurable.

## Allowed Files

- `discord-bot/index.js`
- `discord-bot/settings.json`
- `discord-bot/logs.json`
- `.dev-flow/tasks/task-002.md`

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

- Detect basic spam indicators:
  - repeated identical messages by the same user in a short window
  - excessive message rate by the same user in a short window
  - repeated mentions above a configurable threshold
- Ignore bot messages and direct messages.
- Attempt to delete offending messages only when the bot has permission.
- Record moderation events to `logs.json` with timestamp, guild ID, channel ID, user ID, action, reason, and message metadata.
- Keep thresholds in `settings.json` with sane defaults if no settings exist.
- Fail gracefully when message deletion is not permitted.
- Do not introduce SQLite in this task unless package-change approval has already been granted.

## Acceptance Criteria

- [ ] Spam checks are deterministic and easy to review in code.
- [ ] A repeated-message spam case can trigger a logged `delete_message` action.
- [ ] A high-rate message case can trigger a logged moderation event.
- [ ] Mention spam can trigger a logged moderation event.
- [ ] Permission failures are logged or warned without crashing the bot.
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

Then send test messages in a private test guild.

## Implementation Notes

Prefer small helper functions for rate tracking, repeated-message detection, mention counting, and event logging. Use in-memory windows for task-002; durable storage can be added later when SQLite dependency approval is resolved.

## Review Notes

To be completed by Codex.
