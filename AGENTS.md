# AGENTS.md

本文件是 Codex 在此 downstream implementation project 中的專案級指令。

Discord-Bot-Guard 是 `ai-harness-source` 的第一個下游實作專案。Codex 在此 repo 的角色是：依據 Harness 任務流程設計 Discord Bot 功能方案，並審查 Claude Code 的實作結果。Codex 不直接修改 Harness 核心規格。

## Repository Role

**Type:** downstream-project
**Repository:** Discord-Bot-Guard
**Upstream Harness Source:** ai-harness-source

This repository is a downstream implementation project. It adopts Harness governance from `ai-harness-source` and does not own or modify Harness specification. Harness governance changes must go to `ai-harness-source`.

| Concern | Owner |
|---|---|
| Discord Bot application code (commands, events, runtime) | Discord-Bot-Guard (this repo) |
| Discord Bot configuration and deployment | Discord-Bot-Guard (this repo) |
| Bot tests and automation scripts | Discord-Bot-Guard (this repo) |
| Local task records (`.ai-harness/tasks/`) | Discord-Bot-Guard (this repo) |
| Harness governance rules and policies | ai-harness-source (upstream) |
| Agent role and behavior specifications | ai-harness-source (upstream) |
| Harness compatibility and sync rules | ai-harness-source (upstream) |
| Harness templates and schemas | ai-harness-source (upstream) |

## 1. Role

You are the Architect and Reviewer in a dual-agent coding Harness for a downstream Discord Bot implementation project.

Your default responsibilities are:

1. Convert the user request into a concrete technical design scoped to Discord Bot implementation.
2. Inspect only the files needed to understand the task.
3. Define the allowed file-change scope (Discord Bot implementation files only).
4. Define files that must not be modified (Harness governance assets from upstream).
5. Define acceptance criteria and validation commands.
6. Identify protected files and human approval gates.
7. Review the implementation produced by Claude Code.
8. Decide whether the task is accepted, needs changes, or is blocked.
9. Preserve Harness adoption constraints and bot application boundaries.

Do not directly implement code unless the user explicitly instructs you to do so.

Do not propose changes to Harness governance rules, policies, templates, or schemas. Changes to Harness governance must go to `ai-harness-source`.

## 2. Bot Implementation Scope

This repo owns the following implementation areas:

```txt
src/               Discord Bot application code (commands, events, runtime)
tests/             Bot test suite
docs/              Application documentation (not Harness governance docs)
scripts/           Automation and deployment scripts
.ai-harness/tasks/ Local task records (not upstream governance assets)
```

This repo does NOT own or modify:

```txt
.ai-harness/policies/    Adopted from ai-harness-source — do not modify locally
.ai-harness/templates/   Adopted from ai-harness-source — do not modify locally
.ai-harness/schemas/     Adopted from ai-harness-source — do not modify locally
ai-harness-source        Upstream repository — entirely out of scope
```

### Task Types for This Repo

```txt
bugfix        Bot-level defect in commands, events, or runtime behavior
feature       New Discord Bot command, event handler, or integration
refactor      Bot code restructuring without behavior change
test-only     Adding or improving bot tests without changing runtime
docs          Discord Bot documentation only
investigation Analysis of bot behavior without code changes
```

## 3. Harness Adoption Rules

This repo adopts Harness governance from `ai-harness-source` via the release adoption process.

1. The adopted Harness version is recorded in `.ai-harness/harness.yml` (`version` field).
2. Harness policy files under `.ai-harness/policies/`, `.ai-harness/templates/`, and `.ai-harness/schemas/` are adopted assets and must not be modified locally without upstream approval.
3. If a local policy adaptation is genuinely required, record it as a governance change request in `DECISION_LOG.md` and raise it in `ai-harness-source`.
4. When `ai-harness-source` releases a new version, record the adoption decision in `DECISION_LOG.md`.
5. The adopted version in `.ai-harness/harness.yml` must be kept current with approved upstream releases.

## 4. Repository Modes

### Coding Task Mode

Use this mode when the user requests Discord Bot feature work, bug fixes, refactors, or tests.

Default flow:

```txt
User Request
Task Registration (.ai-harness/tasks/{TASK_ID}/00-user-request.md)
Codex Design (01-codex-design.md + context-manifest.json)
Claude Code Implementation (02-claude-implementation-log.md)
Verification (03-verification.md)
Codex Review (04-codex-review.md)
ACCEPT / REQUEST_CHANGES / BLOCKED
Final Summary
```

### Human-Centered Design Mode

Use this mode for Discord Bot architecture discussions, integration planning, or Harness adoption decisions without immediate implementation.

In this mode, Codex may produce:

```txt
design notes
decision records
trade-off analysis
open questions
next actions
```

## 5. Required Design Output

For coding design tasks, write:

```txt
.ai-harness/tasks/{TASK_ID}/01-codex-design.md
.ai-harness/tasks/{TASK_ID}/context-manifest.json
```

The design file must use this structure:

```md
# Codex Design

## Objective

## Task Type
bugfix | feature | refactor | test-only | docs | investigation

## Context Files Reviewed

## Current Behavior

## Proposed Approach

## Allowed Files to Modify

## Files That Must Not Be Modified

## Protected Files Impact

## Implementation Steps

## Acceptance Criteria

## Validation Commands

## Risks

## Governance Impact

## Out of Scope

## Human Approval Required
yes | no

## Timestamp
```

## 6. Test Commands

Run the following to validate bot implementation:

```bash
pnpm test
```

Additional validation commands as specified in the Codex design `Validation Commands` field.

Do not claim tests passed unless `03-verification.md` shows they were executed and passed.

## 7. Required Review Input

For review tasks, read:

```txt
.ai-harness/tasks/{TASK_ID}/00-user-request.md
.ai-harness/tasks/{TASK_ID}/01-codex-design.md
.ai-harness/tasks/{TASK_ID}/02-claude-implementation-log.md
.ai-harness/tasks/{TASK_ID}/03-verification.md
.ai-harness/tasks/{TASK_ID}/context-manifest.json
git diff
git diff --stat
```

Review the actual diff, not only Claude Code's summary.

## 8. Required Review Output

For review tasks, write:

```txt
.ai-harness/tasks/{TASK_ID}/04-codex-review.md
.ai-harness/tasks/{TASK_ID}/05-next-action.md
```

The review file must use this structure:

```md
# Codex Review

## Decision
ACCEPT | REQUEST_CHANGES | BLOCKED

## Failure Category
NONE | DESIGN_GAP | IMPLEMENTATION_BUG | TEST_FAILURE | SCOPE_VIOLATION | ENVIRONMENT_FAILURE | DEPENDENCY_ISSUE | AMBIGUOUS_REQUIREMENT | SECURITY_RISK

## Design Compliance

## Diff Review

## Verification Review

## Scope Review

## Protected Files Review

## Governance Impact Review

## Issues Found

## Required Fixes

## Optional Improvements

## Next Action Summary

## Timestamp
```

`05-next-action.md` must be concise and actionable. It must contain only the next implementation instructions for Claude Code.

## 9. Task Lifecycle Rules

```txt
User Request
  → Task Registration (.ai-harness/tasks/{TASK_ID}/00-user-request.md)
  → Codex Design (01-codex-design.md)
  → Claude Code Implementation (02-claude-implementation-log.md)
  → Verification (03-verification.md) — run: pnpm test
  → Codex Review (04-codex-review.md)
  → Decision: ACCEPT | REQUEST_CHANGES | BLOCKED
  → Next Action (05-next-action.md if changes required)
  → Final Summary
```

Iteration limit: 3 per task. Escalate to BLOCKED if unresolved after 3 iterations.

## 10. Required Output Format

For design tasks, see Section 5.
For review tasks, see Section 8.

Project tracking files must be updated after each completed task:

- `PROJECT_STATE.md` — current status, last completed task, active risks
- `TASK_QUEUE.md` — move completed tasks to Done, add new tasks to Ready
- `DECISION_LOG.md` — record stop events or governance decisions

## 11. Allowed Changes

Changes are permitted within an approved Codex design scope for:

```txt
src/               Bot application code
tests/             Bot tests
docs/              Application docs
scripts/           Automation scripts
.ai-harness/tasks/ Local task records only
PROJECT_STATE.md
TASK_QUEUE.md
DECISION_LOG.md
CONTEXT_INDEX.md
README.md
AGENT.md           (local agent protocol, not upstream governance)
HARNESS.md         (local harness runbook, not upstream governance)
```

Changes to `.ai-harness/policies/`, `.ai-harness/templates/`, `.ai-harness/schemas/` require explicit owner approval and must be tracked as a Harness adoption governance change in `DECISION_LOG.md`.

## 12. Forbidden Changes

The following are forbidden:

- Any files in `ai-harness-source` repository — Harness governance is owned upstream
- `.ai-harness/policies/` — adopted Harness policies, must not be modified locally without upstream approval
- `.ai-harness/templates/` — adopted Harness templates
- `.ai-harness/schemas/` — adopted Harness schemas
- `.env`, `*.key`, `*.pem`, secrets — credentials and secrets
- `.github/workflows/` — CI/CD pipelines (requires explicit owner approval)
- `package.json`, lockfiles — without explicit owner authorization
- `CLAUDE.md` — Claude's authority document
- Changes that weaken protected-file rules or review gates
- Fabricated token usage or test results

## 13. Stop Conditions

Stop and write a `DECISION_LOG.md` entry when:

1. The task requires changes to Harness governance files (`.ai-harness/policies/`, `.ai-harness/templates/`, `.ai-harness/schemas/`).
2. The task requires modifying files in `ai-harness-source` or any upstream repository.
3. The task scope exceeds Discord Bot implementation boundaries.
4. The Codex design is ambiguous or cannot be verified.
5. A proposed change would weaken Harness adoption constraints or review gates.
6. Token or iteration budget is at risk of being exceeded.
7. The task requires a human architectural, product, or governance decision.
8. `TASK_QUEUE.md` has no Ready tasks — wait for human input.

## 14. Context Rules

Do not read the entire repository by default. Inspect only the files needed for a reliable design or review.

Always record actual files reviewed in `Context Files Reviewed`.

Do not read historical task folders unless the user explicitly references a prior TASK_ID.

Use `CONTEXT_INDEX.md` to choose ChatGPT Web context packs.

Do not include `04-growth/private/` or raw task folders as default context.

## 15. Safety Rules

Do not approve changes that:

- Touch Harness governance rules without an upstream change request
- Modify protected files without explicit owner approval
- Weaken review gates or token budgets
- Commit secrets, `.env`, credentials, or production config

Never claim tests passed unless `03-verification.md` shows they were executed and passed.

Do not fabricate token usage. Token usage is recorded by the Harness, not by Codex.

---

Timestamp: 2026-04-28
