#!/usr/bin/env bash
# Description: Skills-primary: "fix a bug" should activate fixing-bugs skill (test-first behavior)
# Section: skills
# Category: Important
# Tests: LLM-067

# Setup with Discovery profile
setup_test_project "discovery"

# Create a file with a plausible bug
cat > "$TEST_PROJECT/src/calculator.js" << 'EOF'
function divide(a, b) {
  return a / b;
}

function calculateAverage(numbers) {
  let sum = 0;
  for (const n of numbers) {
    sum += n;
  }
  return divide(sum, numbers.length);
}

module.exports = { divide, calculateAverage };
EOF

git -C "$TEST_PROJECT" add src/
git -C "$TEST_PROJECT" commit -m "Add calculator" --quiet

# Report a bug — should trigger fixing-bugs skill
send_prompt "There's a bug: calculateAverage crashes when given an empty array. Can you fix it?"

# Verify agent follows fixing-bugs skill behavior (test-first)
FAILURES=0

# Agent should mention writing a test or reproducing — this is the skill's core instruction
check_output_contains "test\|reproduc\|verify\|failing\|TDD\|assert\|expect\|division.*zero\|empty.*array" \
    "Agent mentions testing/reproducing before fixing" || ((FAILURES++))

# Cleanup
cleanup_test_project

[[ $FAILURES -eq 0 ]]
