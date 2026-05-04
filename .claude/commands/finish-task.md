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
