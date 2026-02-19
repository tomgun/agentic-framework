# Manual Operations Guide

**Purpose**: Run these commands yourself to check project state **without consuming AI tokens**. Save agent sessions for actual development work.

## Philosophy

The agent maintains documentation. You can **read that documentation directly** instead of asking the agent. This is faster and costs zero tokens.

## Quick Information Retrieval

### Framework Version

**Check your framework version:**
```bash
cat STACK.md | grep "Version:"
```

**Check for framework updates:**
```bash
curl -s https://api.github.com/repos/tomgun/agentic-framework/releases/latest | grep '"tag_name"'
```

**Upgrade framework:**
```bash
# See ../UPGRADING.md for full guide

# Download new framework to temp location
cd /tmp
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v<VERSION>.tar.gz | tar xz

# Run upgrade tool FROM the new framework
bash /tmp/agentic-framework-<VERSION>/.agentic/tools/upgrade.sh /path/to/your-project

# Clean up
rm -rf /tmp/agentic-framework-<VERSION>
```

### What's the current status?
```bash
cat STATUS.md
```
Shows: current focus, what's in progress, next steps, known issues, roadmap.

### What happened recently?
```bash
tail -50 JOURNAL.md
```
Shows: last few session summaries with what was done, next steps, blockers.

### How do I run/test this project?
```bash
cat STACK.md
```
Shows: build commands, test commands, tech stack, constraints.

### Where do I find things?
```bash
cat CONTEXT_PACK.md
```
Shows: architecture overview, where key modules are, how things work.

### What features exist and their status?
```bash
grep "^## F-" spec/FEATURES.md | head -20
```
Shows: feature IDs and names.

For full feature details:
```bash
cat spec/FEATURES.md
```

### What needs human attention?
```bash
cat HUMAN_NEEDED.md
```
Shows: decisions, blockers, or issues that need human judgment.

## Automated Health Checks

```bash
bash .agentic/tools/doctor.sh       # Check project structure
bash .agentic/tools/doctor.sh --full # Comprehensive verification
bash .agentic/tools/report.sh       # Feature status summary
```

**📖 Full script documentation (30+ scripts)**: [`DEVELOPER_GUIDE.md#automation--scripts`](DEVELOPER_GUIDE.md#automation--scripts)

## Context Gathering (Before Agent Session)

**Goal**: Load up with context so you can give the agent a focused task.

### Full context load (5 minutes)
```bash
# 1. Current state
cat STATUS.md
tail -30 JOURNAL.md

# 2. Quick health check
bash .agentic/tools/doctor.sh

# 3. Feature status
bash .agentic/tools/report.sh

# 4. What needs attention
cat HUMAN_NEEDED.md
```

Now you know:
- What's happening
- What's broken
- What's next
- What needs decisions

### Quick context load (1 minute)
```bash
# Just read these three files
cat STATUS.md
tail -20 JOURNAL.md  
cat HUMAN_NEEDED.md
```

## Finding Specific Information

### Find where a feature is implemented
```bash
# Search for feature ID in codebase
grep -r "@feature F-0005" src/ lib/ components/

# Check FEATURES.md for listed code paths
grep -A 30 "^## F-0005:" spec/FEATURES.md | grep "Code:"
```

### Find acceptance criteria for a feature
```bash
cat spec/acceptance/F-0005.md
```

### Find decisions related to a topic
```bash
# Search ADR titles
ls spec/adr/ | grep -i "auth"

# Search ADR content
grep -i "authentication" spec/adr/*.md
```

### Find why something was done
```bash
# Check JOURNAL.md for context
grep -i "authentication" JOURNAL.md

# Check LESSONS.md for caveats
grep -i "auth" spec/LESSONS.md
```

### Check test coverage for a feature
```bash
grep -A 20 "^## F-0005:" spec/FEATURES.md | grep -A 5 "^- Tests:"
```

## Where to Log Things

Use the right file for the right purpose:

| What you have | Where it goes | Command |
|--------------|---------------|---------|
| Development idea, task, or reminder | `TODO.md` | `ag todo "description"` |
| Needs human action (PR review, credentials, decision) | `HUMAN_NEEDED.md` | `bash .agentic/tools/blocker.sh add "Title" "type" "Details"` |
| Bug or technical debt | `ISSUES.md` | `bash .agentic/tools/quick_issue.sh "Title" "Details"` |
| New capability to spec | `FEATURES.md` | `bash .agentic/tools/feature.sh add "Title"` |

**Do NOT** put development tasks in HUMAN_NEEDED.md — reserve it for items requiring human action.

## Quick Edits (Humans Can Do These)

You can **edit spec files directly** without talking to the agent. The agent will pick up your changes on next session.

### Add a new feature
Edit `spec/FEATURES.md` directly:

```markdown
## F-0010: New feature name
- Parent: none
- Dependencies: none
- Complexity: M
- Status: planned
- PRD: spec/PRD.md#section
- Requirements: R-0005
- NFRs: none
- Acceptance: spec/acceptance/F-0010.md
- Verification:
  - Accepted: no
- Implementation:
  - State: none
  - Code:
- Tests:
  - Test strategy: unit
  - Unit: todo
  - Integration: n/a
  - Acceptance: todo
- Technical debt:
- Lessons/caveats:
- Notes:
```

Then tell the agent: "Implement F-0010"

### Update priorities
Edit `STATUS.md` - change "Next up" section with new order or new features.

### Mark a decision resolved
Edit `HUMAN_NEEDED.md` - move item from "Active" to "Resolved" section.

### Note a new issue
Add to `STATUS.md` under "Known issues / risks".

### Add acceptance criteria
Create or edit `spec/acceptance/F-####.md` with specific criteria.

### Record a decision
Create `spec/adr/ADR-####-short-title.md` from template.

### Add a reference
Add entry to `spec/REFERENCES.md` for papers/docs you found useful.

### Update architecture notes
Edit `spec/TECH_SPEC.md` to add architectural details.

### Create a task
Run `bash .agentic/tools/task.sh "Task title"` or create manually in `spec/tasks/`.

**The agent will see your changes** when it reads these files at session start.

## Time-Saving Patterns

### Pattern 1: Quick Status Check (30 seconds)
```bash
cat STATUS.md | head -30
```
Tells you: what's happening, what's next.

### Pattern 2: Session Prep (2 minutes)
```bash
cat STATUS.md
tail -20 JOURNAL.md
bash .agentic/tools/doctor.sh
```
Now you can tell the agent: "Continue working on F-0005" with context.

### Pattern 3: Feature Planning (5 minutes)
```bash
# See what's planned
grep "Status: planned" spec/FEATURES.md

# Check dependencies
bash .agentic/tools/feature_graph.sh

# See blockers
cat HUMAN_NEEDED.md
```
Now you know which features can be started.

### Pattern 4: Code Review Prep (3 minutes)
```bash
# Check what changed
tail -50 JOURNAL.md

# Verify docs updated
bash .agentic/tools/verify.sh

# Check test coverage
bash .agentic/tools/coverage.sh
```
Now you can review code with context.

## Common Questions → Commands

**📖 For comprehensive command reference, see [`DEVELOPER_GUIDE.md#quick-reference`](DEVELOPER_GUIDE.md#quick-reference)**

| Question | Command |
|----------|---------|
| What's the current focus? | `cat STATUS.md` |
| What happened in last session? | `tail -30 JOURNAL.md` |
| How do I run tests? | `grep -i "test" STACK.md` |
| What features are done? | `grep "Status: shipped" spec/FEATURES.md` |
| What's blocking progress? | `cat HUMAN_NEEDED.md` |
| Is documentation current? | `bash .agentic/tools/verify.sh` |
| Where is feature X implemented? | `grep -r "@feature F-000X" .` |

See DEVELOPER_GUIDE.md for the full table with 20+ commands.

## When to Ask the Agent vs. Look Yourself

### Look it up yourself (saves tokens):
- ✅ Current status and priorities
- ✅ What happened recently
- ✅ How to run/build/test
- ✅ Where code is located
- ✅ Feature list and status
- ✅ Known issues and blockers
- ✅ Architecture overview

### Ask the agent (requires context/judgment):
- 🤖 "How should I implement feature X?"
- 🤖 "Why does this test fail?"
- 🤖 "What's the best approach for Y?"
- 🤖 "Continue working on F-0005"
- 🤖 "Review this code change"
- 🤖 "Debug this issue"

## Pro Tips

1. **Bookmark key files**: Keep STATUS.md, JOURNAL.md, HUMAN_NEEDED.md open in editor
2. **Alias common commands**: 
   ```bash
   alias astatus='cat STATUS.md'
   alias ajournal='tail -50 JOURNAL.md'
   alias acheck='bash .agentic/tools/doctor.sh'
   ```
3. **Use grep with color**: `grep --color=always ...` makes patterns visible
4. **Pipe to less**: `bash .agentic/tools/report.sh | less` for long output
5. **Save outputs**: `bash .agentic/tools/feature_graph.sh --save` creates docs/feature_graph.md

## Dashboard View (Copy-Paste This)

Run this before starting work to get a complete picture:

```bash
#!/bin/bash
echo "=== AGENTIC PROJECT DASHBOARD ==="
echo ""
echo "▶ CURRENT FOCUS"
head -10 STATUS.md | tail -5
echo ""
echo "▶ LAST SESSION"
tail -15 JOURNAL.md | head -10
echo ""
echo "▶ HEALTH CHECK"
bash .agentic/tools/doctor.sh | grep -E "(OK|Missing|Validation)" | head -10
echo ""
echo "▶ FEATURES SUMMARY"
bash .agentic/tools/report.sh | head -10
echo ""
echo "▶ NEEDS ATTENTION"
grep -A 3 "^### HN-" HUMAN_NEEDED.md | head -15 || echo "None"
echo ""
echo "=== Ready to work! ==="
```

Save as `dashboard.sh` and run before each work session.

## Related Documentation

- Full tool documentation: `.agentic/tools/` (each script has inline help)
- Token efficiency: `.agentic/token_efficiency/reading_protocols.md`
- Agent workflows: `.agentic/workflows/dev_loop.md`
- Quick start: `.agentic/START_HERE.md`

