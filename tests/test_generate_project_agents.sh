#!/usr/bin/env bash
# Unit tests for generate-project-agents.sh
# Tests stack detection, rule application, CUSTOMIZED guard

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEN_SCRIPT="$FRAMEWORK_ROOT/.agentic/lib/tools/generate-project-agents.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

test_case() {
    local name="$1"
    echo -n "Testing: $name... "
}

pass() {
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
}

fail() {
    local msg="${1:-}"
    echo -e "${RED}FAIL${NC}"
    [[ -n "$msg" ]] && echo "  $msg"
    ((FAILED++))
}

# Create a test project that mimics a React/Next.js project
setup_react_project() {
    TEST_DIR=$(mktemp -d "/tmp/gen-agents-test-XXXXXX")
    mkdir -p "$TEST_DIR/.agentic/lib/tools"
    mkdir -p "$TEST_DIR/.agentic/lib/presets"
    mkdir -p "$TEST_DIR/.agentic/lib/agents/specialization"
    mkdir -p "$TEST_DIR/.agentic/lib/agents/claude/subagents"
    mkdir -p "$TEST_DIR/.agentic/session"

    # Copy scripts
    cp "$GEN_SCRIPT" "$TEST_DIR/.agentic/lib/tools/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/paths.sh" "$TEST_DIR/.agentic/lib/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/presets/profiles.conf" "$TEST_DIR/.agentic/lib/presets/"

    # Copy specialization rules
    cp "$FRAMEWORK_ROOT/.agentic/lib/agents/specialization/react.conf" "$TEST_DIR/.agentic/lib/agents/specialization/"

    # Copy generic agents (if they exist — removed in v2 simplification)
    for agent_file in implementation-agent.md test-agent.md review-agent.md; do
      [[ -f "$FRAMEWORK_ROOT/.agentic/lib/agents/claude/subagents/$agent_file" ]] && \
        cp "$FRAMEWORK_ROOT/.agentic/lib/agents/claude/subagents/$agent_file" "$TEST_DIR/.agentic/lib/agents/claude/subagents/"
    done

    # Create package.json with React
    cat > "$TEST_DIR/package.json" << 'EOF'
{
  "dependencies": {
    "react": "^19.0.0",
    "next": "^15.0.0"
  }
}
EOF

    # Create STACK.md
    cat > "$TEST_DIR/STACK.md" << 'EOF'
## Settings
- profile: discovery

## Languages & runtimes
- Language(s): TypeScript

## Frameworks & libraries
- App framework: Next.js
- UI framework: React
EOF

    cd "$TEST_DIR"
    git init -q 2>/dev/null || true
    git add -A 2>/dev/null && git commit -q -m "init" 2>/dev/null || true
}

setup_go_project() {
    TEST_DIR=$(mktemp -d "/tmp/gen-agents-test-XXXXXX")
    mkdir -p "$TEST_DIR/.agentic/lib/tools"
    mkdir -p "$TEST_DIR/.agentic/lib/presets"
    mkdir -p "$TEST_DIR/.agentic/lib/agents/specialization"
    mkdir -p "$TEST_DIR/.agentic/lib/agents/claude/subagents"
    mkdir -p "$TEST_DIR/.agentic/session"

    cp "$GEN_SCRIPT" "$TEST_DIR/.agentic/lib/tools/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/paths.sh" "$TEST_DIR/.agentic/lib/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/presets/profiles.conf" "$TEST_DIR/.agentic/lib/presets/"
    cp "$FRAMEWORK_ROOT/.agentic/lib/agents/specialization/go.conf" "$TEST_DIR/.agentic/lib/agents/specialization/"
    # Copy generic agents (if they exist — removed in v2 simplification)
    for agent_file in implementation-agent.md test-agent.md review-agent.md; do
      [[ -f "$FRAMEWORK_ROOT/.agentic/lib/agents/claude/subagents/$agent_file" ]] && \
        cp "$FRAMEWORK_ROOT/.agentic/lib/agents/claude/subagents/$agent_file" "$TEST_DIR/.agentic/lib/agents/claude/subagents/"
    done

    # Go detection: go.mod file
    cat > "$TEST_DIR/go.mod" << 'EOF'
module example.com/myapp

go 1.22
EOF

    cat > "$TEST_DIR/STACK.md" << 'EOF'
## Settings
- profile: discovery
EOF

    cd "$TEST_DIR"
    git init -q 2>/dev/null || true
    git add -A 2>/dev/null && git commit -q -m "init" 2>/dev/null || true
}

cleanup_test_env() {
    cd "$SCRIPT_DIR"
    [[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"
}

# =============================================================================
# Detection Tests
# =============================================================================

test_case "React detection via package.json"
setup_react_project
output=$(bash .agentic/lib/tools/generate-project-agents.sh --dry-run 2>&1)
if echo "$output" | grep -q "React"; then
    pass
else
    fail "React not detected. Output: $output"
fi
cleanup_test_env

test_case "Go detection via go.mod"
setup_go_project
output=$(bash .agentic/lib/tools/generate-project-agents.sh --dry-run 2>&1)
if echo "$output" | grep -q "Go"; then
    pass
else
    fail "Go not detected. Output: $output"
fi
cleanup_test_env

test_case "No false positives on empty project"
TEST_DIR=$(mktemp -d "/tmp/gen-agents-test-XXXXXX")
mkdir -p "$TEST_DIR/.agentic/lib/tools" "$TEST_DIR/.agentic/lib/presets" "$TEST_DIR/.agentic/lib/agents/specialization" "$TEST_DIR/.agentic/lib/agents/claude/subagents" "$TEST_DIR/.agentic/session"
cp "$GEN_SCRIPT" "$TEST_DIR/.agentic/lib/tools/"
cp "$FRAMEWORK_ROOT/.agentic/lib/paths.sh" "$TEST_DIR/.agentic/lib/"
cp "$FRAMEWORK_ROOT/.agentic/lib/settings.sh" "$TEST_DIR/.agentic/lib/"
cp "$FRAMEWORK_ROOT/.agentic/lib/presets/profiles.conf" "$TEST_DIR/.agentic/lib/presets/"
cp "$FRAMEWORK_ROOT/.agentic/lib/agents/specialization/"*.conf "$TEST_DIR/.agentic/lib/agents/specialization/"
cat > "$TEST_DIR/STACK.md" << 'EOF'
## Settings
- profile: discovery
EOF
cd "$TEST_DIR"
git init -q 2>/dev/null || true
output=$(bash .agentic/lib/tools/generate-project-agents.sh --dry-run 2>&1)
if echo "$output" | grep -q "No matching tech stacks"; then
    pass
else
    fail "Should report no stacks. Output: $output"
fi
cleanup_test_env

# =============================================================================
# Generation Tests
# =============================================================================

test_case "Generate creates files in subagents-project/"
setup_react_project
bash .agentic/lib/tools/generate-project-agents.sh > /dev/null 2>&1
if [ -f ".agentic/lib/agents/claude/subagents-project/implementation-agent.md" ]; then
    pass
else
    fail "implementation-agent.md not created in subagents-project/"
fi
cleanup_test_env

test_case "Generated files have AUTO-GENERATED marker"
setup_react_project
bash .agentic/lib/tools/generate-project-agents.sh > /dev/null 2>&1
if head -1 .agentic/lib/agents/claude/subagents-project/implementation-agent.md | grep -q "AUTO-GENERATED"; then
    pass
else
    fail "Missing AUTO-GENERATED marker"
fi
cleanup_test_env

test_case "Generated files contain purpose suffix and key dirs"
setup_react_project
bash .agentic/lib/tools/generate-project-agents.sh > /dev/null 2>&1
if grep -q "React/TypeScript" .agentic/lib/agents/claude/subagents-project/implementation-agent.md && \
   grep -q "src/components/" .agentic/lib/agents/claude/subagents-project/implementation-agent.md; then
    pass
else
    fail "Missing React purpose suffix or key dirs"
fi
cleanup_test_env

# =============================================================================
# CUSTOMIZED Guard Tests
# =============================================================================

test_case "CUSTOMIZED files are not overwritten"
setup_react_project
# Generate first
bash .agentic/lib/tools/generate-project-agents.sh > /dev/null 2>&1
# Mark as customized
sed -i.bak 's/AUTO-GENERATED/CUSTOMIZED/' .agentic/lib/agents/claude/subagents-project/implementation-agent.md
echo "# My custom content" >> .agentic/lib/agents/claude/subagents-project/implementation-agent.md
# Re-generate
bash .agentic/lib/tools/generate-project-agents.sh > /dev/null 2>&1
if grep -q "My custom content" .agentic/lib/agents/claude/subagents-project/implementation-agent.md; then
    pass
else
    fail "CUSTOMIZED file was overwritten"
fi
cleanup_test_env

# =============================================================================
# Multiple Stack Detection
# =============================================================================

test_case "Go: generates implementation agent with purpose and key dirs"
setup_go_project
bash .agentic/lib/tools/generate-project-agents.sh > /dev/null 2>&1
if [ -f ".agentic/lib/agents/claude/subagents-project/implementation-agent.md" ] && \
   grep -q "Go applications" .agentic/lib/agents/claude/subagents-project/implementation-agent.md && \
   grep -q "cmd/" .agentic/lib/agents/claude/subagents-project/implementation-agent.md; then
    pass
else
    fail "Missing Go implementation agent or content"
fi
cleanup_test_env

test_case "Go: agents without overrides are not generated"
setup_go_project
bash .agentic/lib/tools/generate-project-agents.sh > /dev/null 2>&1
# test-agent and review-agent have no overrides in go.conf (Layer A detection only)
if [ ! -f ".agentic/lib/agents/claude/subagents-project/test-agent.md" ] && \
   [ ! -f ".agentic/lib/agents/claude/subagents-project/review-agent.md" ]; then
    pass
else
    fail "Agents without overrides should not be generated"
fi
cleanup_test_env

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "========================="
echo "Results: $PASSED passed, $FAILED failed"
echo "========================="

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
