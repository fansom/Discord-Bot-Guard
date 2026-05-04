---
task_id: task-004
status: ready
assigned_to: claude_code
created: 2026-05-04
depends_on: [task-001, task-002, task-003]
estimated_lines: 240
---

# Task: Implement Structured Activity Logging

## Objective

Create a structured activity logging layer for Discord Bot Guard so moderation actions, admin configuration changes, startup events, and relevant failures are recorded consistently.

## Context

The spec requires all operations to have log records and names SQLite as the intended database. The current project only has JSON files and no SQLite dependency in `discord-bot/package.json`. This task should complete structured JSON logging first, and only introduce SQLite after explicit package-change approval.

## Allowed Files

- `discord-bot/index.js`
- `discord-bot/settings.json`
- `discord-bot/logs.json`
- `.dev-flow/tasks/task-004.md`

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

## Protected Files Impact

SQLite persistence requires adding a database dependency and possibly changing package or lock files. Those files are protected by project policy unless the owner explicitly authorizes package changes. Do not implement SQLite dependency changes in this task without that approval.

## Requirements

- Centralize logging into a helper that writes structured entries to `logs.json`.
- Include fields for timestamp, event type, guild ID, channel ID, user ID, action, reason, and metadata where applicable.
- Log startup success/failure, moderation actions, permission failures, and admin configuration changes.
- Keep `logs.json` valid even if it starts empty or malformed; handle recovery conservatively.
- Keep log writes synchronous or serialized enough to avoid corrupting JSON during normal bot operation.
- Document in comments where SQLite can replace JSON persistence after approval.

## Acceptance Criteria

- [ ] Moderation actions from task-002 use the centralized logger.
- [ ] Admin command changes from task-003 use the centralized logger.
- [ ] Startup and permission failure events are logged consistently.
- [ ] `logs.json` remains valid JSON after multiple writes.
- [ ] `node --check discord-bot/index.js` passes.
- [ ] No package or lock files are modified unless explicit approval is documented.

## Validation Commands

```bash
node --check discord-bot/index.js
```

Manual validation:

```bash
cd discord-bot
npm start
```

Then trigger a configuration change and a moderation action in a private test guild.

## Implementation Notes

This task may refactor existing logging code, but should not alter command names or moderation thresholds except where needed to route events through the central logger.

## Review Notes

To be completed by Codex.
