#!/usr/bin/env bash
# Description: Agent is aware that ag done will block on stale docs and proactively updates them
# Section: workflow
# Category: Important
# Tests: LLM-101
#
# Tests that the agent understands the docs_gate enforcement and doesn't
# just "try ag done and see what happens."

# Setup with formal profile
setup_test_project "formal"

cat > "$TEST_PROJECT/STACK.md" << 'EOF'
# Stack

## Settings
- profile: formal
- feature_tracking: yes
- docs_gate: blocking

## Docs
| Path | Triggers | Description |
|------|----------|-------------|
| CHANGELOG.md | feature_done | Change log |
EOF

cat > "$TEST_PROJECT/CHANGELOG.md" << 'EOF'
# Changelog
## v0.1.0
- Initial release
EOF

mkdir -p "$TEST_PROJECT/.agentic/spec/contracts" "$TEST_PROJECT/.agentic/spec"
cat > "$TEST_PROJECT/.agentic/spec/FEATURES.md" << 'EOF'
# Features
## F-0100: Rate Limiting
**Status**: in_progress
EOF
cat > "$TEST_PROJECT/.agentic/spec/contracts/F-0100.yaml" << 'EOF'
id: F-0100
name: Rate Limiting
lifecycle: implementing
description: Add rate limiting to API.
assertions:
  - id: AC-001
    text: Requests are rate-limited
    type: behavioral
EOF

git -C "$TEST_PROJECT" add -A
git -C "$TEST_PROJECT" commit -m "Feature implementation" --quiet

# Ask about completing the feature
send_prompt "F-0100 (Rate Limiting) is implemented and tests pass. The PR was merged. I need to run ag done. Note that docs_gate is set to blocking and I haven't updated the CHANGELOG yet."

# Verify agent behavior
FAILURES=0

# Agent should warn about stale docs blocking ag done
check_output_contains "CHANGELOG\|docs.*gate\|blocking\|stale\|update.*doc\|doc.*fresh\|before.*ag done" \
    "Agent warns about stale docs blocking ag done" || ((FAILURES++))

# Agent should suggest updating docs BEFORE running ag done
check_output_contains "update.*before\|first.*update\|update.*CHANGELOG\|doc.*before.*done" \
    "Agent suggests updating docs before ag done" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
