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
