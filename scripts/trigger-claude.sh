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
