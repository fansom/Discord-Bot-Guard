#!/usr/bin/env bash
set -euo pipefail

# Initialize the minimal AI workflow system described by:
# - minimal-ai-workflow-system.md
# - full-automation-plan-c.md
#
# Safe by default:
# - Existing files are kept.
# - Re-run with FORCE=1 ./setup.sh to overwrite generated files.

FORCE="${FORCE:-0}"

write_file() {
  local path="$1"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"

  if [ -f "$path" ] && [ "$FORCE" != "1" ]; then
    echo "skip existing: $path"
    return 0
  fi

  cat > "$path"
  echo "write: $path"
}

make_executable() {
  local path="$1"
  if [ -f "$path" ]; then
    chmod +x "$path" 2>/dev/null || true
  fi
}

echo "Initializing AI workflow structure..."

mkdir -p \
  .dev-flow/context \
  .dev-flow/handoff \
  .dev-flow/triggers \
  .dev-flow/tasks \
  .dev-flow/automation \
  .claude/commands \
  scripts

write_file ".dev-flow/context/claude-role.md" <<'EOF_CLAUDE_ROLE'
# Claude Code Role

Version: 1.0
Token target: keep the working context under 3,000 tokens per task.

## Mission

You are the implementation agent. Your job is to take exactly one ready task, read only the task file and its context pack, implement the requested code change, and hand the result back to Codex for review.

Always finish by notifying Codex. Do not silently complete work without creating the handoff.

## Required Startup Flow

1. Read this role file.
2. If `.dev-flow/handoff/to-claude.md` exists, read it first. It contains Codex review feedback or revision instructions.
3. Find the next task with `status: ready`, unless the handoff names a specific task.
4. Read:
   - `.dev-flow/tasks/task-XXX.md`
   - `.dev-flow/tasks/task-XXX.context.md`
5. Change the task status to `in_progress` before editing.

## Implementation Rules

- Work on one task only.
- Stay inside the files allowed by the task.
- Do not modify workflow governance or role files unless the task explicitly allows it.
- Do not change unrelated code.
- Do not commit secrets, `.env` files, private keys, or credentials.
- Prefer small, reviewable changes.
- Add or update tests when the task acceptance criteria require it.
- If requirements are unclear, stop and write the blocker in the task log.

## Finish Flow

When the implementation is complete:

1. Update the implementation notes inside the task file.
2. Set `status: review`.
3. Write `.dev-flow/handoff/to-codex.md` with:
   - task id
   - summary
   - files changed
   - implementation details
   - known risks
   - validation commands and results
4. Write `.dev-flow/triggers/codex-review-needed.flag` containing the task id.
5. Remove `.dev-flow/handoff/to-claude.md` after applying its feedback.

## Never Do

- Do not mark a task `done`; only Codex can do that after review.
- Do not approve your own work.
- Do not fabricate test results.
- Do not broaden scope because you noticed adjacent improvements.
- Do not read the full repository unless the task context is insufficient.
EOF_CLAUDE_ROLE

write_file ".dev-flow/context/codex-role.md" <<'EOF_CODEX_ROLE'
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
EOF_CODEX_ROLE

write_file ".dev-flow/context/chatgpt-role.md" <<'EOF_CHATGPT_ROLE'
# ChatGPT Web Role

Version: 1.0
Primary responsibility: high-level product and architecture design.

## Mission

You convert human goals into a compact, implementation-ready `.dev-flow/spec.md` that Codex can split into small tasks.

## Output Contract

Write or update `.dev-flow/spec.md` with:

- Objective
- User-facing behavior
- Non-goals
- Architecture notes
- Data model or config changes
- Files or modules likely involved
- Acceptance criteria
- Suggested task breakdown
- Risks and open questions

## Design Rules

- Keep the spec concise enough for Codex to read in one pass.
- Prefer explicit interfaces, paths, and examples.
- Avoid implementation detail that belongs in task files unless it constrains correctness.
- Call out any required human decisions.
- Do not edit code.
- Do not approve implementation.

## Handoff To Codex

After the spec is ready, ask Codex to:

1. Read `.dev-flow/spec.md`.
2. Create task files under `.dev-flow/tasks/`.
3. Generate a compact context pack for each task.
4. Define acceptance criteria and validation commands.
EOF_CHATGPT_ROLE

write_file ".claude/commands/check-task.md" <<'EOF_CHECK_TASK'
# Check Task

Use this command to pick up the next implementation task.

## Steps

1. Read the Claude role:

   ```bash
   cat .dev-flow/context/claude-role.md
   ```

2. Check for Codex feedback:

   ```bash
   if [ -f .dev-flow/handoff/to-claude.md ]; then
     echo "Codex feedback found:"
     cat .dev-flow/handoff/to-claude.md
   fi
   ```

3. Find the next ready task:

   ```bash
   NEXT_TASK="$(grep -l '^status: ready' .dev-flow/tasks/task-*.md 2>/dev/null | sort | head -1 || true)"

   if [ -z "$NEXT_TASK" ]; then
     echo "No ready task found."
     exit 0
   fi

   TASK_ID="$(basename "$NEXT_TASK" .md)"
   echo "Next task: $TASK_ID"
   ```

4. Read the task and context pack:

   ```bash
   cat "$NEXT_TASK"

   CONTEXT_FILE="${NEXT_TASK%.md}.context.md"
   if [ -f "$CONTEXT_FILE" ]; then
     cat "$CONTEXT_FILE"
   else
     echo "Missing context pack: $CONTEXT_FILE"
     exit 1
   fi
   ```

5. Mark the task in progress before editing:

   ```bash
   sed -i.bak 's/^status: ready/status: in_progress/' "$NEXT_TASK" && rm -f "$NEXT_TASK.bak"
   ```

6. Implement only the requested task.

7. When complete, run `/finish-task`.
EOF_CHECK_TASK

write_file ".claude/commands/finish-task.md" <<'EOF_FINISH_TASK'
# Finish Task

Use this command after completing one Claude Code implementation task. It prepares the Codex review handoff.

## Steps

1. Find the active task:

   ```bash
   CURRENT_TASK="$(grep -l '^status: in_progress' .dev-flow/tasks/task-*.md 2>/dev/null | sort | head -1 || true)"

   if [ -z "$CURRENT_TASK" ]; then
     echo "No in-progress task found."
     exit 1
   fi

   TASK_ID="$(basename "$CURRENT_TASK" .md)"
   echo "Finishing task: $TASK_ID"
   ```

2. Update the implementation notes in the task file:

   - summary of work completed
   - files changed
   - validation commands run
   - validation results
   - known risks or follow-up notes

3. Move the task to review:

   ```bash
   sed -i.bak 's/^status: in_progress/status: review/' "$CURRENT_TASK" && rm -f "$CURRENT_TASK.bak"
   ```

4. Create `.dev-flow/handoff/to-codex.md`:

   ```bash
   mkdir -p .dev-flow/handoff .dev-flow/triggers

   cat > .dev-flow/handoff/to-codex.md <<EOF
   ---
   from: claude_code
   to: codex
   task_id: $TASK_ID
   timestamp: $(date -Iseconds)
   ---

   # Task Ready For Review

   ## Task ID
   $TASK_ID

   ## Summary
   [Replace this with a concise implementation summary.]

   ## Files Changed
   [List changed files.]

   ## Implementation Details
   [Describe important behavior and edge cases.]

   ## Validation
   [List commands run and results. Do not claim tests passed unless they did.]

   ## Known Risks
   [List risks or write "None known."]

   ## Review Requests
   [Call out specific areas Codex should inspect.]
   EOF
   ```

5. Notify Codex:

   ```bash
   echo "$TASK_ID" > .dev-flow/triggers/codex-review-needed.flag
   ```

6. Clean stale feedback after applying it:

   ```bash
   rm -f .dev-flow/handoff/to-claude.md
   ```

7. Tell the human or orchestration layer:

   ```text
   Task is ready for Codex review. Ask Codex to read .dev-flow/handoff/to-codex.md.
   ```
EOF_FINISH_TASK

write_file ".claude/commands/read-spec.md" <<'EOF_READ_SPEC'
# Read Spec

Read the current workflow spec:

```bash
cat .dev-flow/spec.md
```

Use this only for orientation. Claude Code should normally work from a task file and its context pack, not from the full spec.
EOF_READ_SPEC

write_file ".dev-flow/spec.md" <<'EOF_SPEC'
# Workflow Spec

Status: draft

## Objective

Describe the product or engineering goal here.

## User-Facing Behavior

- Describe expected behavior.

## Non-Goals

- List work that is explicitly out of scope.

## Architecture Notes

- List relevant modules, APIs, services, or data flow.

## Acceptance Criteria

- [ ] Criteria are specific and testable.

## Suggested Task Breakdown

- task-001: First small implementation task.

## Risks And Open Questions

- None yet.
EOF_SPEC

write_file ".dev-flow/status.json" <<'EOF_STATUS'
{
  "workflow_status": "initialized",
  "current_task": null,
  "review_needed": false,
  "last_updated": null
}
EOF_STATUS

write_file ".dev-flow/tasks/task-template.md" <<'EOF_TASK_TEMPLATE'
---
task_id: task-XXX
status: ready
assigned_to: claude_code
created: YYYY-MM-DD
depends_on: []
estimated_lines: 100
---

# Task: Short Title

## Objective

## Context

## Allowed Files

## Forbidden Files

## Requirements

## Acceptance Criteria

- [ ] 

## Validation Commands

```bash
pnpm test
```

## Implementation Notes

To be completed by Claude Code.

## Review Notes

To be completed by Codex.
EOF_TASK_TEMPLATE

write_file ".dev-flow/tasks/task-template.context.md" <<'EOF_CONTEXT_TEMPLATE'
# task-XXX Context Pack

## Relevant Spec Excerpt

## Relevant Files

## Interfaces And Constraints

## Validation Notes
EOF_CONTEXT_TEMPLATE

write_file ".dev-flow/handoff/to-codex.template.md" <<'EOF_TO_CODEX_TEMPLATE'
---
from: claude_code
to: codex
task_id: task-XXX
timestamp: YYYY-MM-DDTHH:MM:SSZ
---

# Task Ready For Review

## Task ID

## Summary

## Files Changed

## Implementation Details

## Validation

## Known Risks

## Review Requests
EOF_TO_CODEX_TEMPLATE

write_file ".dev-flow/handoff/to-claude.template.md" <<'EOF_TO_CLAUDE_TEMPLATE'
---
from: codex
to: claude_code
task_id: task-XXX
timestamp: YYYY-MM-DDTHH:MM:SSZ
action: revise
---

# Review Requires Changes

## Task ID

## Required Fixes

## Evidence

## Validation To Re-run
EOF_TO_CLAUDE_TEMPLATE

write_file ".dev-flow/automation/workflow-state.json" <<'EOF_WORKFLOW_STATE'
{
  "workflow_id": null,
  "status": "idle",
  "total_tasks": 0,
  "completed_tasks": 0,
  "current_cycle": 0,
  "current_actor": null,
  "current_task": null,
  "started_at": null,
  "last_updated": null,
  "retry_count": 0,
  "max_retries": 3,
  "errors": []
}
EOF_WORKFLOW_STATE

write_file ".dev-flow/automation/cycle-log.md" <<'EOF_CYCLE_LOG'
# Automation Cycle Log

No cycles have run yet.
EOF_CYCLE_LOG

write_file ".dev-flow/automation/completion-report.md" <<'EOF_COMPLETION_REPORT'
# Completion Report

Workflow has not completed yet.
EOF_COMPLETION_REPORT

write_file "scripts/create-task-context.sh" <<'EOF_CREATE_TASK_CONTEXT'
#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
  echo "Usage: $0 task-XXX"
  exit 1
fi

TASK_FILE=".dev-flow/tasks/${TASK_ID}.md"
CONTEXT_FILE=".dev-flow/tasks/${TASK_ID}.context.md"
SPEC_FILE=".dev-flow/spec.md"

if [ ! -f "$TASK_FILE" ]; then
  echo "Missing task file: $TASK_FILE"
  exit 1
fi

if [ ! -f "$SPEC_FILE" ]; then
  echo "Missing spec file: $SPEC_FILE"
  exit 1
fi

cat > "$CONTEXT_FILE" <<EOF
# ${TASK_ID} Context Pack

Generated: $(date -Iseconds)

## Task

$(cat "$TASK_FILE")

## Spec Snapshot

$(cat "$SPEC_FILE")

## Notes For Claude Code

- Read only the files needed for this task.
- Stay within the allowed file scope.
- Record validation commands and results before finishing.
EOF

echo "Created $CONTEXT_FILE"
EOF_CREATE_TASK_CONTEXT

write_file "scripts/check-context-size.sh" <<'EOF_CHECK_CONTEXT_SIZE'
#!/usr/bin/env bash
set -euo pipefail

echo "Context size estimate"
echo "====================="

find .dev-flow/context .dev-flow/tasks -type f \( -name "*.md" -o -name "*.json" \) 2>/dev/null | sort | while read -r file; do
  words="$(wc -w < "$file" | tr -d ' ')"
  tokens=$(( (words * 4 + 2) / 3 ))
  printf "%-55s ~%s tokens\n" "$file:" "$tokens"
done
EOF_CHECK_CONTEXT_SIZE

write_file "scripts/watch-for-codex.sh" <<'EOF_WATCH_CODEX'
#!/usr/bin/env bash
set -euo pipefail

FLAG_FILE=".dev-flow/triggers/codex-review-needed.flag"

echo "Watching for Codex review requests..."
echo "Press Ctrl+C to stop."

while true; do
  if [ -f "$FLAG_FILE" ]; then
    TASK_ID="$(cat "$FLAG_FILE")"
    TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

    echo ""
    echo "========================================="
    echo "Codex review needed"
    echo "========================================="
    echo "Time: $TIMESTAMP"
    echo "Task ID: $TASK_ID"
    echo "Handoff: .dev-flow/handoff/to-codex.md"
    echo ""
    echo "Ask Codex to review .dev-flow/handoff/to-codex.md"
    echo "========================================="

    if command -v osascript >/dev/null 2>&1; then
      osascript -e "display notification \"Task $TASK_ID is ready for review\" with title \"Codex review needed\"" || true
    fi

    if command -v notify-send >/dev/null 2>&1; then
      notify-send "Codex review needed" "Task $TASK_ID is ready for review" || true
    fi

    echo "$TIMESTAMP - Task $TASK_ID ready for review" >> .dev-flow/review-notifications.log
    rm -f "$FLAG_FILE"
    sleep 10
  fi

  sleep 30
done
EOF_WATCH_CODEX

write_file "scripts/clean-handoff.sh" <<'EOF_CLEAN_HANDOFF'
#!/usr/bin/env bash
set -euo pipefail

rm -f .dev-flow/handoff/to-codex.md
rm -f .dev-flow/handoff/to-claude.md
rm -f .dev-flow/triggers/codex-review-needed.flag
rm -f .dev-flow/automation/trigger-claude.flag
rm -f .dev-flow/automation/trigger-codex.flag

echo "Cleaned workflow handoff and trigger files."
EOF_CLEAN_HANDOFF

write_file "scripts/check-completion.sh" <<'EOF_CHECK_COMPLETION'
#!/usr/bin/env bash
set -euo pipefail

total="$(find .dev-flow/tasks -maxdepth 1 -name 'task-*.md' ! -name '*.context.md' 2>/dev/null | wc -l | tr -d ' ')"
done_count="$(grep -l '^status: done' .dev-flow/tasks/task-*.md 2>/dev/null | wc -l | tr -d ' ')"

echo "Tasks complete: $done_count / $total"

if [ "$total" != "0" ] && [ "$total" = "$done_count" ]; then
  echo "All tasks are done."
  exit 0
fi

echo "Workflow still has open tasks."
exit 1
EOF_CHECK_COMPLETION

write_file "scripts/notify-human.sh" <<'EOF_NOTIFY_HUMAN'
#!/usr/bin/env bash
set -euo pipefail

TYPE="${1:-INFO}"
MESSAGE="${2:-Workflow notification}"

echo ""
echo "========================================="
echo "Human notification"
echo "========================================="
echo "Type: $TYPE"
echo "Message: $MESSAGE"
echo "========================================="

if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MESSAGE\" with title \"AI workflow - $TYPE\"" || true
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send "AI workflow - $TYPE" "$MESSAGE" || true
fi
EOF_NOTIFY_HUMAN

write_file "scripts/trigger-claude.sh" <<'EOF_TRIGGER_CLAUDE'
#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
  echo "Usage: $0 task-XXX"
  exit 1
fi

mkdir -p .dev-flow/automation

cat > .dev-flow/automation/claude-command.txt <<EOF
Read .dev-flow/context/claude-role.md
Read .dev-flow/tasks/${TASK_ID}.md
Read .dev-flow/tasks/${TASK_ID}.context.md

Implement the task exactly as scoped. When finished, run /finish-task.
EOF

echo "$TASK_ID" > .dev-flow/automation/trigger-claude.flag
echo "Claude trigger prepared for $TASK_ID"
echo "Command file: .dev-flow/automation/claude-command.txt"
EOF_TRIGGER_CLAUDE

write_file "scripts/trigger-codex.sh" <<'EOF_TRIGGER_CODEX'
#!/usr/bin/env bash
set -euo pipefail

TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
  if [ -f .dev-flow/triggers/codex-review-needed.flag ]; then
    TASK_ID="$(cat .dev-flow/triggers/codex-review-needed.flag)"
  else
    echo "Usage: $0 task-XXX"
    exit 1
  fi
fi

mkdir -p .dev-flow/automation

cat > .dev-flow/automation/codex-command.txt <<EOF
Read .dev-flow/context/codex-role.md
Read .dev-flow/handoff/to-codex.md
Read .dev-flow/tasks/${TASK_ID}.md
Read .dev-flow/tasks/${TASK_ID}.context.md

Review the implementation. Decide PASS, FAIL, or BLOCKED.
EOF

echo "$TASK_ID" > .dev-flow/automation/trigger-codex.flag
echo "Codex trigger prepared for $TASK_ID"
echo "Command file: .dev-flow/automation/codex-command.txt"
EOF_TRIGGER_CODEX

write_file "scripts/automation-engine.sh" <<'EOF_AUTOMATION_ENGINE'
#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_DIR=".dev-flow/automation"
STATE_FILE="$WORKFLOW_DIR/workflow-state.json"
LOG_FILE="$WORKFLOW_DIR/cycle-log.md"

mkdir -p "$WORKFLOW_DIR"

log_cycle() {
  local status="$1"
  local task_id="$2"
  local message="$3"

  cat >> "$LOG_FILE" <<EOF
## $(date '+%Y-%m-%d %H:%M:%S') - $status

Task: $task_id

$message

---

EOF
}

find_next_ready_task() {
  local task_file
  task_file="$(grep -l '^status: ready' .dev-flow/tasks/task-*.md 2>/dev/null | sort | head -1 || true)"
  if [ -n "$task_file" ]; then
    basename "$task_file" .md
  fi
}

all_tasks_done() {
  local total
  local done_count
  total="$(find .dev-flow/tasks -maxdepth 1 -name 'task-*.md' ! -name '*.context.md' 2>/dev/null | wc -l | tr -d ' ')"
  done_count="$(grep -l '^status: done' .dev-flow/tasks/task-*.md 2>/dev/null | wc -l | tr -d ' ')"
  [ "$total" != "0" ] && [ "$total" = "$done_count" ]
}

cat > "$STATE_FILE" <<EOF
{
  "workflow_id": "$(date +%Y%m%d-%H%M%S)",
  "status": "running",
  "started_at": "$(date -Iseconds)",
  "last_updated": "$(date -Iseconds)"
}
EOF

echo "Automation engine started."
echo "This script prepares trigger files for Claude Code and Codex; it does not call external AI CLIs directly."

cycle=1
while true; do
  if all_tasks_done; then
    echo "All tasks are done."
    ./scripts/notify-human.sh SUCCESS "All workflow tasks are done and ready for human merge review." || true
    break
  fi

  task_id="$(find_next_ready_task || true)"
  if [ -z "$task_id" ]; then
    echo "No ready task found. Waiting..."
    sleep 30
    continue
  fi

  echo "Cycle $cycle: preparing Claude Code trigger for $task_id"
  ./scripts/trigger-claude.sh "$task_id"
  log_cycle "TRIGGER_CLAUDE" "$task_id" "Claude Code trigger file created."

  echo "Waiting for $task_id to move to review..."
  while ! grep -q '^status: review' ".dev-flow/tasks/${task_id}.md" 2>/dev/null; do
    sleep 10
  done

  echo "Preparing Codex trigger for $task_id"
  ./scripts/trigger-codex.sh "$task_id"
  log_cycle "TRIGGER_CODEX" "$task_id" "Codex review trigger file created."

  echo "Waiting for Codex to finish review..."
  while grep -q '^status: review' ".dev-flow/tasks/${task_id}.md" 2>/dev/null; do
    sleep 10
  done

  cycle=$((cycle + 1))
done
EOF_AUTOMATION_ENGINE

make_executable "scripts/create-task-context.sh"
make_executable "scripts/check-context-size.sh"
make_executable "scripts/watch-for-codex.sh"
make_executable "scripts/clean-handoff.sh"
make_executable "scripts/check-completion.sh"
make_executable "scripts/notify-human.sh"
make_executable "scripts/trigger-claude.sh"
make_executable "scripts/trigger-codex.sh"
make_executable "scripts/automation-engine.sh"

echo ""
echo "AI workflow initialization complete."
echo ""
echo "Created structure:"
echo "  .dev-flow/context/"
echo "  .dev-flow/handoff/"
echo "  .dev-flow/triggers/"
echo "  .dev-flow/tasks/"
echo "  .dev-flow/automation/"
echo "  .claude/commands/"
echo "  scripts/"
echo ""
echo "Next steps:"
echo "  1. Edit .dev-flow/spec.md"
echo "  2. Ask Codex to split the spec into tasks"
echo "  3. Ask Claude Code to run /check-task"
