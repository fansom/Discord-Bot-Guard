# Check Task

Use this command to pick up the next implementation task.

## Steps

1. Read the Claude role:

   ```bash
   cat .dev-flow/context/claude-role.md
   ```

2. Check for Codex feedback:

   ```bash
   if [ -f .dev-flow/handoff/to-claude.md ]; then
     echo "Codex feedback found:"
     cat .dev-flow/handoff/to-claude.md
   fi
   ```

3. Find the next ready task:

   ```bash
   NEXT_TASK="$(grep -l '^status: ready' .dev-flow/tasks/task-*.md 2>/dev/null | sort | head -1 || true)"

   if [ -z "$NEXT_TASK" ]; then
     echo "No ready task found."
     exit 0
   fi

   TASK_ID="$(basename "$NEXT_TASK" .md)"
   echo "Next task: $TASK_ID"
   ```

4. Read the task and context pack:

   ```bash
   cat "$NEXT_TASK"

   CONTEXT_FILE="${NEXT_TASK%.md}.context.md"
   if [ -f "$CONTEXT_FILE" ]; then
     cat "$CONTEXT_FILE"
   else
     echo "Missing context pack: $CONTEXT_FILE"
     exit 1
   fi
   ```

5. Mark the task in progress before editing:

   ```bash
   sed -i.bak 's/^status: ready/status: in_progress/' "$NEXT_TASK" && rm -f "$NEXT_TASK.bak"
   ```

6. Implement only the requested task.

7. When complete, run `/finish-task`.
