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
