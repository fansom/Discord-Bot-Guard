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
