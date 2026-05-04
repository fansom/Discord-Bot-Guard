# Task Breakdown

Source: `.dev-flow/spec.md`
Spec updated: 2026-05-04 20:17:20
Generated: 2026-05-04

## Summary

The updated spec defines Discord Bot Guard as a Discord.js v14, Node.js 20+ bot for server management and security protection. The required feature areas are bot runtime setup, spam-message filtering, administrator commands, and activity logging.

The current implementation under `discord-bot/` is a legacy team-up bot, not a guard bot, and `discord-bot/index.js` currently contains mojibake and syntax errors. The task plan therefore starts with a runtime baseline replacement before adding moderation features.

## Full Task List

### task-001: Establish Guard Bot Runtime Baseline

Create a clean Discord.js v14 bot entrypoint that validates `DISCORD_TOKEN`, connects to Discord, exposes ready/error/warn handlers, keeps minimal runtime health behavior, and prepares placeholder message handling.

Dependencies: none

Status: ready

### task-002: Implement Message Spam Filtering

Add automatic spam detection for repeated messages, excessive message rate, and mention spam. Enforce conservatively through message deletion when permitted and structured logging when actions or failures occur.

Dependencies: task-001

Status: ready after task-001

### task-003: Add Admin Command Interface

Add administrator-only slash commands for viewing guard settings, enabling/disabling filtering, setting a moderation log channel, and adjusting basic spam thresholds.

Dependencies: task-001, task-002

Status: ready after task-002

### task-004: Implement Structured Activity Logging

Centralize structured activity logging for startup events, moderation actions, configuration changes, and operational failures. Use `logs.json` first; SQLite requires separate package-change approval.

Dependencies: task-001, task-002, task-003

Status: ready after task-003

## Cross-Cutting Acceptance Criteria

- The bot can connect to Discord when valid credentials are supplied.
- Spam messages can be detected and handled.
- Administrators can manage guard behavior through slash commands.
- Guard operations produce structured log records.
- `node --check discord-bot/index.js` passes after each implementation task.
- Protected Harness governance files are not modified.

## Protected Scope Notes

The spec names SQLite as a technical requirement, but `discord-bot/package.json` does not currently include a SQLite dependency. Package and lockfile changes are protected by project policy unless explicitly authorized. The current breakdown implements JSON-backed structured logging first and records SQLite as a follow-up requiring owner approval.

## First Claude Code Task

Start with `task-001`.
