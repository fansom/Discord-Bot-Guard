# task-003 Context Pack

## Task Description

Implement an administrator-facing slash command interface for viewing and changing Discord Bot Guard settings. Commands should configure spam filtering and log-channel behavior per guild.

## Dependencies

- Depends on `task-001` for stable startup.
- Depends on `task-002` for the spam-filter settings being configured.
- Requires bot application command permissions in Discord.

## Acceptance Criteria

- Slash commands register without syntax/runtime errors.
- Admin permission checks prevent non-admin configuration changes.
- Settings are persisted by guild ID.
- Configuration changes are logged.
- Ephemeral responses are used for management actions.
- `node --check discord-bot/index.js` succeeds.

## Relevant Code Files

- `discord-bot/index.js` - command definitions, registration, and interaction handling.
- `discord-bot/settings.json` - per-guild command-configurable settings.
- `discord-bot/logs.json` - audit log entries for configuration changes.
- `discord-bot/package.json` - dependency reference only.

## Interfaces And Constraints

- Use Discord.js v14 `SlashCommandBuilder`, `REST`, and `Routes`.
- Keep command names ASCII.
- Do not expose token values or environment details in Discord replies.
- Do not modify package files unless separately approved.

## Validation Notes

Use `node --check` for syntax validation. Runtime validation requires testing commands in a guild where the bot has application command scope.
