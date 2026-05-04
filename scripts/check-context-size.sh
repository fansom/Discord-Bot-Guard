#!/usr/bin/env bash
set -euo pipefail

echo "Context size estimate"
echo "====================="

find .dev-flow/context .dev-flow/tasks -type f \( -name "*.md" -o -name "*.json" \) 2>/dev/null | sort | while read -r file; do
  words="$(wc -w < "$file" | tr -d ' ')"
  tokens=$(( (words * 4 + 2) / 3 ))
  printf "%-55s ~%s tokens\n" "$file:" "$tokens"
done
