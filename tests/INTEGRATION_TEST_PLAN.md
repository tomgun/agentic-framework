# Integration Test Plan

**Purpose**: Validate that the Agentic AF framework actually works in real scenarios, not just static checks.

**Status**: Planned (not yet automated)

---

## Why Integration Tests?

The current `validate_framework.sh` only checks:
- ✅ Files exist
- ✅ Scripts are executable
- ✅ Content patterns match

But it does NOT verify:
- ❌ Scripts actually run correctly
- ❌ Upgrade process works end-to-end
- ❌ Agent prompts produce expected behavior
- ❌ Cross-environment compatibility (Claude, Cursor, Copilot)

---

## Test Categories

### 1. Installation Tests

| Test ID | Description | Steps | Expected |
|---------|-------------|-------|----------|
| INST-01 | Fresh install via install.sh | `bash install.sh /tmp/test-project` | .agentic/ created, VERSION set |
| INST-02 | Install to non-empty project | Create files, run install.sh | Existing files preserved |
| INST-03 | Install without target arg | `bash install.sh` (in project dir) | Works in current dir |

### 2. Initialization Tests

| Test ID | Description | Steps | Expected |
|---------|-------------|-------|----------|
| INIT-01 | Core profile scaffold | Run scaffold.sh with Core | OVERVIEW.md, JOURNAL.md created |
| INIT-02 | Core+PM profile scaffold | Run scaffold.sh with Core+PM | + spec/FEATURES.md, STATUS.md |
| INIT-03 | Scaffold idempotency | Run scaffold.sh twice | No duplicates, no errors |

### 3. Upgrade Tests (CRITICAL - Current Bug Area)

| Test ID | Description | Steps | Expected |
|---------|-------------|-------|----------|
| UPG-01 | Basic upgrade | Install v0.8.0, upgrade to v0.9.2 | STACK.md updated, .upgrade_pending created |
| UPG-02 | STACK.md formats | Test all formats: `- Version:`, `Version:`, indented | All updated correctly |
| UPG-03 | Backup created | Run upgrade | agentic-backup-* exists |
| UPG-04 | Rollback works | Upgrade, then rollback | Original state restored |
| UPG-05 | Dry run mode | `DRY_RUN=yes bash upgrade.sh` | No changes made |

### 4. Tool Tests

| Test ID | Description | Steps | Expected |
|---------|-------------|-------|----------|
| TOOL-01 | quick_feature.sh | `bash quick_feature.sh "Test feature"` | F-0001 added to FEATURES.md |
| TOOL-02 | quick_issue.sh | `bash quick_issue.sh "Test bug"` | I-0001 added to ISSUES.md |
| TOOL-03 | journal.sh | `bash journal.sh "Test entry"` | Entry in JOURNAL.md |
| TOOL-04 | status.sh | `bash status.sh focus "Working on X"` | STATUS.md updated |
| TOOL-05 | doctor.py | `python3 doctor.py` | No errors on valid project |
| TOOL-06 | validate_specs.py | On valid project | Exit 0, no errors |
| TOOL-07 | version_check.sh | After upgrade | Detects version mismatch |

### 5. Agent Simulation Tests

| Test ID | Description | Steps | Expected |
|---------|-------------|-------|----------|
| AGT-01 | Session start detection | Create .upgrade_pending, check session_start.md flow | Agent reads file, follows TODO |
| AGT-02 | WIP tracking | Create .agentic/WIP.md, simulate crash | Recovery info preserved |
| AGT-03 | Feature complete flow | Mark feature done | FEATURES.md updated |

### 6. Cross-Environment Tests

| Test ID | Description | Environment | Expected |
|---------|-------------|-------------|----------|
| ENV-01 | Claude Code hooks | Claude Code | Hooks fire, logs created |
| ENV-02 | Cursor integration | Cursor | CLAUDE.md instructions followed |
| ENV-03 | Copilot integration | GitHub Copilot | copilot-instructions.md applied |

---

## Test Runner Script (Future)

```bash
#!/usr/bin/env bash
# tests/run_integration_tests.sh

# Create temp directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "Running integration tests in $TEST_DIR..."

# INST-01: Fresh install
echo "Test INST-01: Fresh install..."
mkdir -p "$TEST_DIR/inst-01"
bash install.sh "$TEST_DIR/inst-01"
if [[ -d "$TEST_DIR/inst-01/.agentic" && -f "$TEST_DIR/inst-01/.agentic/VERSION" ]]; then
  echo "✓ INST-01 passed"
else
  echo "✗ INST-01 FAILED"
fi

# UPG-01: Basic upgrade
# ... more tests ...
```

---

## Manual Test Scenarios

For agent behavior testing (requires actual LLM):

### Scenario A: New Project Setup
1. Start with empty repo
2. Run: "I want to use Agentic AF to build a CLI todo app"
3. **Verify**: Agent runs install.sh, scaffold.sh, creates correct structure

### Scenario B: Upgrade Detection
1. Upgrade framework in running project
2. Say to agent: "Read .agentic/.upgrade_pending and follow the TODO list in it."
3. **Verify**: Agent reads file, completes TODO, deletes marker

### Scenario C: Feature Development Cycle
1. Say: "Add a feature for dark mode"
2. **Verify**: Agent creates acceptance criteria, implements, updates FEATURES.md

---

## CI/CD Integration (Future)

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests
on: [push, pull_request]

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run integration tests
        run: bash tests/run_integration_tests.sh
```

---

## Known Issues to Test

Based on user reports:

1. **UPG-BUG-01**: STACK.md version not updated
   - Root cause: Unknown (need debugging)
   - Test: UPG-02 covers this
   
2. **UPG-BUG-02**: .upgrade_pending not created
   - Root cause: Possibly FRAMEWORK_VERSION empty
   - Test: UPG-01 covers this

---

## Running Tests Manually (Now)

Until automation is ready:

```bash
# Create test project
mkdir /tmp/test-agentic && cd /tmp/test-agentic

# Test install
bash /path/to/agentic-framework/install.sh .

# Verify
ls -la .agentic/
cat .agentic/VERSION

# Test upgrade (after installing older version)
bash /path/to/new-framework/.agentic/tools/upgrade.sh .

# Verify
cat STACK.md | grep Version
cat .agentic/.upgrade_pending
```

---

## Success Criteria

Before each release:
- [ ] All INST-* tests pass
- [ ] All UPG-* tests pass  
- [ ] All TOOL-* tests pass
- [ ] Manual scenario A works
- [ ] Manual scenario B works

---

## Contributing to Tests

When adding framework features:
1. Add test case to relevant category
2. Document expected behavior
3. If automatable, add to `run_integration_tests.sh`
4. If agent-dependent, add to manual scenarios

