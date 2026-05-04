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
