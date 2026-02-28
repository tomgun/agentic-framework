---
name: updating-documentation
description: >
  Update documentation and README files after feature work. Use when user says
  "update docs", "write readme", "document this", "add docs", "update
  documentation", or after completing a feature that needs doc updates.
  Do NOT use for: code changes (use implementing-features), reading docs for
  understanding (use exploring-codebase).
compatibility: "Requires Claude Code with file access."
allowed-tools: [Read, Write, Edit, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Updating Documentation

Sync documentation with code changes to keep docs accurate and current.

## Instructions

### Step 1: Identify What Changed

Check what code was modified:
```bash
git diff --stat HEAD~1
```

Determine which docs need updating based on the changes.

### Step 2: Update Relevant Docs

Common documentation updates:
- **README.md**: New features, changed setup steps, updated examples
- **CHANGELOG.md**: Entry for the version with what changed
- **API docs**: New endpoints, changed parameters, updated responses
- **Configuration docs**: New settings, changed defaults
- **Architecture docs**: Structural changes, new components

### Step 3: Verify Accuracy

- Code examples in docs should be runnable
- Links should point to existing files
- Version numbers should be current
- Screenshots should reflect current UI (if applicable)

### Step 4: Use Framework Scripts

For framework-managed docs:
```bash
bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"
bash .agentic/tools/status.sh focus "Current state"
```

## Examples

**Example 1: Post-feature documentation**
User says: "Update the docs for the new auth feature"
Steps taken:
1. Read the auth feature code to understand what was added
2. Update README.md with new auth section
3. Add CHANGELOG entry: "Added JWT authentication"
4. Update API docs with new auth endpoints
Result: Documentation matches the implemented feature.

**Example 2: Quick README update**
User says: "Add installation instructions to README"
Steps taken:
1. Read existing README structure
2. Check package.json/setup.py for install commands
3. Write installation section with prerequisites and steps
Result: Clear installation instructions added to README.

## Troubleshooting

**Docs out of sync with code**
Cause: Code changed without doc updates.
Solution: Run `git log --oneline` to find recent changes, then update docs for each relevant change.
