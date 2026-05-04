# task-002 Context Pack

## Task Description

Implement automatic message filtering for spam-like behavior in guild channels. The bot should detect repeated messages, excessive message rate, and mention spam, then delete or log according to permissions and configured thresholds.

## Dependencies

- Depends on `task-001` runtime baseline.
- Requires `MessageContent` intent to be enabled both in code and in the Discord Developer Portal.
- Runtime deletion depends on bot channel permissions.

## Acceptance Criteria

- Repeated identical messages by one user in a short time window are detected.
- Excessive message rate by one user is detected.
- Mention spam is detected.
- Moderation actions and failures are written to `discord-bot/logs.json`.
- The bot does not crash when it lacks delete permissions.
- `node --check discord-bot/index.js` succeeds.

## Relevant Code Files

- `discord-bot/index.js` - message event handling and moderation logic.
- `discord-bot/settings.json` - default moderation thresholds.
- `discord-bot/logs.json` - moderation audit output.
- `discord-bot/package.json` - dependency reference only; avoid edits unless separately approved.

## Interfaces And Constraints

- Do not moderate bots or DMs.
- Keep enforcement conservative to reduce false positives.
- Avoid package changes in this task.
- Use structured JSON log entries, not free-form strings.

## Validation Notes

Static check with `node --check`. Manual testing should use a test Discord guild and messages that intentionally trigger each spam rule.
