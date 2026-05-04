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
