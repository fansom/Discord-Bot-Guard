#!/bin/bash
# .dev-flow/triggers/on-spec-update.sh

SPEC_FILE=".dev-flow/spec.md"
LAST_CHECK_FILE=".dev-flow/.last-check"

# 取得上次檢查的時間戳
if [ -f "$LAST_CHECK_FILE" ]; then
    LAST_MODIFIED=$(cat "$LAST_CHECK_FILE")
else
    LAST_MODIFIED=0
fi

# 取得 spec.md 當前修改時間
CURRENT_MODIFIED=$(stat -f %m "$SPEC_FILE" 2>/dev/null || stat -c %Y "$SPEC_FILE")

# 如果有更新
if [ "$CURRENT_MODIFIED" -gt "$LAST_MODIFIED" ]; then
    echo "偵測到 spec.md 更新!"
    echo "$CURRENT_MODIFIED" > "$LAST_CHECK_FILE"
    
    # 觸發 Claude Code
    claude-code <<EOF
檢查 .dev-flow/spec.md 的最新變更:
1. 識別新增或修改的需求
2. 更新 .dev-flow/tasks/ 中的任務
3. 標記受影響的現有任務
4. 生成變更摘要到 .dev-flow/handoff/updates.md
EOF
else
    echo "無更新"
fi