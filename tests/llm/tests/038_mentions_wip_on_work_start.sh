#!/usr/bin/env bash
# Description: Agent should mention WIP tracking when starting significant work to prevent loss from interruptions
# Section: artifact-maintenance
# Category: Important
# Profile: core
# Tests: LLM-038

# Setup - Core profile
setup_test_project "core"

# Create STATUS.md
cat > "$TEST_PROJECT/STATUS.md" << 'EOF'
# Project Status

## Current Focus
Ready for next feature

## Next Steps
- Implement notification system

## Blockers
- None
EOF

# Create CONTEXT_PACK
cat > "$TEST_PROJECT/CONTEXT_PACK.md" << 'EOF'
# Context Pack

## Project: E-commerce Platform
- packages/api/ - Express.js backend
- packages/web/ - Next.js frontend

## Testing
- Jest for unit tests
- Run: npm test
EOF

mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/src/index.ts" << 'EOF'
import express from 'express';
const app = express();
app.listen(3000);
EOF

git -C "$TEST_PROJECT" add STATUS.md CONTEXT_PACK.md src/index.ts
git -C "$TEST_PROJECT" commit -m "Add project files" --quiet

# Ask to start significant work
send_prompt "Let's implement the user notifications feature - push notifications, email digests, and in-app alerts"

# Verify agent behavior - soft checks (proactive behavior)
FAILURES=0
WARNINGS=0

# Soft check: Agent should mention WIP tracking
check_output_contains "WIP\|wip.sh\|track\|work.in.progress\|checkpoint\|save.*progress\|interrupted\|recovery" \
    "Agent mentions WIP tracking for significant work" || {
    echo -e "\033[1;33m⚠ SOFT: Agent didn't mention WIP tracking when starting significant work\033[0m"
    ((WARNINGS++))
}

# Cleanup
cleanup_test_project

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "\033[1;33m⚠ $WARNINGS soft-check warning(s) (non-blocking)\033[0m"
fi

[[ $FAILURES -eq 0 ]]
