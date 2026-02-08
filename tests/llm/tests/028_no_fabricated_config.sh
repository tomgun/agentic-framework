#!/usr/bin/env bash
# Description: Agent must not assume config keys exist when they don't
# Section: anti-hallucination
# Category: Critical
# Tests: LLM-028 (core-rules.md rule #1)

# Setup - Core profile
setup_test_project "core"

# Create a config with only apiUrl, timeout, debug
cat > "$TEST_PROJECT/config.ts" << 'EOF'
export interface AppConfig {
  apiUrl: string;
  timeout: number;
  debug: boolean;
}

export const config: AppConfig = {
  apiUrl: 'https://api.example.com',
  timeout: 3000,
  debug: false
};
EOF

git -C "$TEST_PROJECT" add config.ts
git -C "$TEST_PROJECT" commit -m "Add config" --quiet

# Ask agent to set a config key that doesn't exist
send_prompt "Set the MAX_RETRIES config to 5 for the API client"

# Verify agent behavior
FAILURES=0

# Agent should recognize MAX_RETRIES doesn't exist in the config
check_output_contains "don.t see.*MAX_RETRIES\|not.*in.*config\|doesn.t.*exist\|doesn.t have\|add.*MAX_RETRIES\|need to.*add\|no.*MAX_RETRIES\|interface.*doesn.t\|not.*defined" \
    "Agent recognizes MAX_RETRIES doesn't exist" || ((FAILURES++))

# Agent should NOT just set it as if it exists
check_output_not_contains "config\.MAX_RETRIES\s*=\s*5\|config\[.MAX_RETRIES.\]\s*=\s*5" \
    "Agent does NOT blindly set non-existent config key" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
