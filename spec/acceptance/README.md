# Framework Acceptance Criteria

This directory contains acceptance criteria for the Agentic AI Framework's own features.

## Purpose

Define what the framework can reliably do at each version. These specs allow:

1. **Version Verification**: Know exactly what each version can do
2. **Regression Testing**: Ensure upgrades don't break existing features
3. **Clear Communication**: Unambiguous feature definitions
4. **Self-Dogfooding**: Apply the framework's spec-driven approach to itself

## Structure

Each file follows the pattern `F-####.md` and contains:

- **Acceptance Criteria**: Testable conditions that define "done"
- **Validation Commands**: Shell commands to verify the criteria
- **Test Scenarios**: Given/When/Then scenarios for manual verification

## Feature Categories

| Range | Category | Description |
|-------|----------|-------------|
| F-0001 - F-0010 | Core | Initialization, profiles, spec-driven development |
| F-0011 - F-0020 | Quality | Programming/testing standards, quality gates |
| F-0021 - F-0030 | Session | Session start/end, journaling, context |
| F-0031 - F-0040 | Multi-Agent | Worktrees, coordination, pipelines |
| F-0041 - F-0050 | Tooling | Scripts, automation, token efficiency |
| F-0051 - F-0060 | Recovery | WIP tracking, error recovery, resilience |
| F-0061 - F-0070 | Developer Experience | Documentation, onboarding, usability |
| F-0071 - F-0080 | Design Principles | Core framework principles as specs |

## Current Coverage

| File | Feature | Status |
|------|---------|--------|
| F-0001.md | Project Initialization | Complete |
| F-0006.md | Acceptance-Driven Development | Complete |
| F-0007.md | Small Batch Development | Complete |
| F-0013.md | Smoke Testing Checklist | Complete |
| F-0016.md | Pre-Commit Quality Gates | Complete |
| F-0021.md | Session Start Protocol | Complete |
| F-0031.md | Multi-Agent Coordination | Complete |
| F-0041.md | Token-Efficient Scripts | Complete |
| F-0051.md | WIP Tracking | Complete |
| F-0055.md | Anti-Hallucination Rules | Complete |
| F-0061.md | DEVELOPER_GUIDE.md | Complete |
| F-0064.md | Script Help Messages | Complete |
| F-0066.md | Template Quality | Complete |
| F-0069.md | Checklist-Driven Workflows | Complete |
| F-0071.md | Token Economics | Complete |
| F-0073.md | Human-Agent Collaboration | Complete |
| F-0074.md | Green Coding Principles | Complete |

## Running Validation

```bash
# Run all validation tests
bash tests/run_tests.sh

# Check specific feature
bash tests/validate_feature.sh F-0001

# Generate coverage report
python .agentic/tools/validate_specs.py spec/
```

## Adding New Acceptance Criteria

When adding a new framework feature:

1. Add feature to `spec/FEATURES.md`
2. Create `spec/acceptance/F-####.md` with:
   - Acceptance criteria (checkboxes)
   - Validation commands
   - Test scenarios
3. Implement the feature
4. Verify all criteria are met
5. Update this README

