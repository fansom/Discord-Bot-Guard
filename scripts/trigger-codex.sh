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
