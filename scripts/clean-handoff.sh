#!/usr/bin/env bash
set -euo pipefail

rm -f .dev-flow/handoff/to-codex.md
rm -f .dev-flow/handoff/to-claude.md
rm -f .dev-flow/triggers/codex-review-needed.flag
rm -f .dev-flow/automation/trigger-claude.flag
rm -f .dev-flow/automation/trigger-codex.flag

echo "Cleaned workflow handoff and trigger files."
