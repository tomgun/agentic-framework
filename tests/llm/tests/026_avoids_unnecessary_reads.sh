#!/usr/bin/env bash
# Description: Agent should not over-read files for simple tasks
# Section: token-efficiency
# Category: Normal
# Profile: core
# Tests: LLM-026

# Setup - Core profile
setup_test_project "discovery"

# Create a simple file to edit
cat > "$TEST_PROJECT/index.js" << 'EOF'
const app = require('express')();

app.get('/', (req, res) => {
  res.send('Hello World');
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
EOF

# Create journal (should NOT be read for this simple task)
mkdir -p "$TEST_PROJECT/.agentic-journal"
cat > "$TEST_PROJECT/.agentic/journal/JOURNAL.md" << 'EOF'
# Development Journal

## Session Log

### 2026-01-20: Major refactor
- Rewrote authentication module
- Added rate limiting
- Updated all API endpoints
- Fixed 15 bugs

### 2026-01-19: Database optimization
- Added indexes on frequently queried columns
- Implemented connection pooling
- Query performance improved 3x
EOF

git -C "$TEST_PROJECT" add index.js .agentic/journal/JOURNAL.md
git -C "$TEST_PROJECT" commit -m "Add files" --quiet

# Ask for a simple code change
send_prompt "Add a console.log statement to index.js that logs 'Request received' when the root endpoint is hit"

# Verify agent behavior
FAILURES=0
WARNINGS=0

# Soft check: Agent should focus on the task
check_output_contains "console.log\|index.js\|Request received\|endpoint" \
    "Agent focuses on the simple code change" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't focus on the code change\033[0m"
    ((WARNINGS++))
}

# Soft check: Agent should not read unrelated files
check_output_not_contains "reading.*JOURNAL\|reading.*FEATURES\|let me check.*JOURNAL" \
    "Agent does NOT read unrelated files for simple task" || {
    echo -e "\033[1;33m⚠ SOFT: Agent read unrelated files for simple task\033[0m"
    ((WARNINGS++))
}

# Cleanup
cleanup_test_project

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "\033[1;33m⚠ $WARNINGS soft-check warning(s) (non-blocking)\033[0m"
fi

[[ $FAILURES -eq 0 ]]
