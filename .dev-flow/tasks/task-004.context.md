# task-004 Context Pack

## Task Description

Implement a consistent structured activity logging layer for bot startup, moderation actions, admin configuration changes, and operational failures. Keep JSON logging as the first implementation because SQLite requires protected package changes.

## Dependencies

- Depends on `task-001` for startup events.
- Depends on `task-002` for moderation events.
- Depends on `task-003` for admin configuration events.
- SQLite upgrade depends on explicit owner approval for package and lockfile changes.

## Acceptance Criteria

- All important bot actions route through one structured logger.
- `logs.json` remains parseable after repeated writes.
- Log entries include timestamp, event type, action, reason, guild/channel/user identifiers when available, and metadata.
- Permission failures and startup events are logged.
- `node --check discord-bot/index.js` succeeds.

## Relevant Code Files

- `discord-bot/index.js` - logging helper and call sites.
- `discord-bot/logs.json` - structured activity log output.
- `discord-bot/settings.json` - guild settings used by log-channel behavior.
- `discord-bot/package.json` - reference only; package edits require approval.

## Interfaces And Constraints

- Use JSON persistence until SQLite package changes are approved.
- Do not write secrets to logs.
- Keep log entries bounded; avoid storing full message content unless needed for moderation evidence and avoid excessive content length.

## Validation Notes

Use `node --check` and manual Discord testing. After manual events, parse `discord-bot/logs.json` to confirm it remains valid JSON.
