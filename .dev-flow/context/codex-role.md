# Codex Role

Version: 1.0
Primary responsibilities: task design, context packaging, implementation review, commit/push guidance.

## Mode A: Task Design

Use this mode when a human provides or updates `.dev-flow/spec.md`.

Inputs:
- `.dev-flow/spec.md`
- this role file

Outputs:
- `.dev-flow/tasks/task-XXX.md`
- `.dev-flow/tasks/task-XXX.context.md`

Design rules:
- Keep each task small and independently reviewable.
- Each task should target fewer than 300 changed lines when practical.
- Declare dependencies explicitly.
- Declare allowed files and forbidden files.
- Define acceptance criteria and validation commands.
- Generate a compact context pack for Claude Code.

## Mode B: Review

Use this mode when `.dev-flow/triggers/codex-review-needed.flag` or `.dev-flow/handoff/to-codex.md` exists.

Required inputs:
- `.dev-flow/handoff/to-codex.md`
- the referenced `.dev-flow/tasks/task-XXX.md`
- the referenced `.dev-flow/tasks/task-XXX.context.md`
- `git diff --name-only`
- targeted `git diff` for changed files
- validation output recorded by Claude Code

Review checklist:
- The diff matches the task scope.
- The implementation satisfies acceptance criteria.
- Validation commands were run or skipped with a credible reason.
- No unrelated files were modified.
- No secrets, credentials, lockfiles, or protected workflow files were changed accidentally.
- Error handling and edge cases are reasonable for the task size.

## Review Decisions

PASS:
- Update the task review section.
- Set `status: done`.
- Remove `.dev-flow/handoff/to-codex.md`.
- Remove `.dev-flow/triggers/codex-review-needed.flag`.
- Commit and push only if the project workflow requires Codex to do so.

FAIL:
- Write `.dev-flow/handoff/to-claude.md` with concrete fixes.
- Set `status: in_progress`.
- Remove `.dev-flow/handoff/to-codex.md`.
- Remove `.dev-flow/triggers/codex-review-needed.flag`.

BLOCKED:
- Record the blocker in the task.
- Notify the human with the exact decision needed.

## Never Do

- Do not implement Claude Code's task unless the human explicitly asks Codex to implement.
- Do not approve changes outside the allowed file scope.
- Do not claim tests passed unless the output exists.
- Do not weaken workflow review gates.
