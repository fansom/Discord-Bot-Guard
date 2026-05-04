# task-001 Context Pack

## Task Description

Establish a clean, runnable Discord Bot Guard baseline by replacing the current legacy team-up bot entrypoint with a minimal Discord.js v14 guard runtime. This task should make the bot start predictably, validate configuration, connect to Discord when credentials exist, and expose stable event hooks for later moderation work.

## Dependencies

- No task dependencies.
- Runtime dependency: existing `discord-bot/package.json` dependencies only.
- Manual Discord validation requires a valid `.env` or environment-provided `DISCORD_TOKEN`; do not edit or commit `.env`.

## Acceptance Criteria

- `node --check discord-bot/index.js` succeeds.
- Missing `DISCORD_TOKEN` produces a clear startup error and exits before login.
- Valid credentials allow the bot to reach the Discord `ready` event.
- Bot message and DM messages are ignored by the placeholder message handler.
- JSON data files remain parseable.

## Relevant Code Files

- `discord-bot/index.js` - main runtime entrypoint to replace/simplify.
- `discord-bot/package.json` - confirms Discord.js, Express, and dotenv are already available; do not edit in this task.
- `discord-bot/settings.json` - existing JSON config store.
- `discord-bot/logs.json` - existing JSON log store.

## Interfaces And Constraints

- Use CommonJS `require` style.
- Do not add dependencies.
- Do not modify secrets or protected Harness governance files.
- Keep future extension points obvious for message filtering, admin commands, and logging.

## Validation Notes

Static validation is `node --check discord-bot/index.js`. Full runtime validation requires real Discord credentials and should be recorded as manual validation if executed.
