# Manual Operations Guide

**Purpose**: Run these commands yourself to check project state **without consuming AI tokens**. Save agent sessions for actual development work.

## Philosophy

The agent maintains documentation. You can **read that documentation directly** instead of asking the agent. This is faster and costs zero tokens.

## Quick Information Retrieval

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

These scripts analyze the project and report issues:

### Check project structure
```bash
bash agentic/tools/doctor.sh
```
**What it checks**:
- All required files exist (STATUS.md, FEATURES.md, etc.)
- Files aren't empty or still template content
- Feature IDs referenced in STATUS.md actually exist
- NFR cross-references are valid

**When to run**: After setup, before starting work, when something feels off.

### Feature status summary
```bash
bash agentic/tools/report.sh
```
**What it shows**:
- Count of features by status (planned/in_progress/shipped)
- Features missing acceptance criteria
- Features needing acceptance validation
- Features with dependency issues

**When to run**: To understand what's done vs. what's left.

### Comprehensive verification
```bash
bash agentic/tools/verify.sh
```
**What it checks**:
- Everything doctor.sh checks
- Cross-references between all spec files
- Broken links to features/NFRs/ADRs
- Missing acceptance files
- Optionally runs test suite

**When to run**: Before committing, before deployments, weekly health check.

### Code annotation coverage
```bash
bash agentic/tools/coverage.sh
```
**What it shows**:
- Which features have code annotations (`@feature F-####`)
- Which implemented features lack annotations
- Orphaned annotations (code references non-existent features)
- Coverage percentage

**When to run**: To verify code traceability, before major reviews.

### Feature dependencies
```bash
bash agentic/tools/feature_graph.sh
# Or save to file:
bash agentic/tools/feature_graph.sh --save
```
**What it shows**:
- Mermaid diagram of feature dependencies
- Which features depend on which
- Status visualization (✓ shipped, ⚙ in progress)

**When to run**: Planning next features, understanding blockers.

### Architecture changes
```bash
bash agentic/tools/arch_diff.sh
# Or compare specific commits:
bash agentic/tools/arch_diff.sh HEAD~5
```
**What it shows**:
- Changes to TECH_SPEC.md since last tag
- Changes to architecture diagrams
- What evolved and when

**When to run**: Reviewing architectural drift, preparing documentation.

## Context Gathering (Before Agent Session)

**Goal**: Load up with context so you can give the agent a focused task.

### Full context load (5 minutes)
```bash
# 1. Current state
cat STATUS.md
tail -30 JOURNAL.md

# 2. Quick health check
bash agentic/tools/doctor.sh

# 3. Feature status
bash agentic/tools/report.sh

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

## Quick Edits (Humans Can Do These)

### Mark a decision resolved
Edit `HUMAN_NEEDED.md` - move item from "Active" to "Resolved" section.

### Update priorities
Edit `STATUS.md` - change "Next up" section with new priorities.

### Note a new issue
Add to `STATUS.md` under "Known issues / risks".

### Add a reference
Add entry to `spec/REFERENCES.md` for papers/docs you found useful.

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
bash agentic/tools/doctor.sh
```
Now you can tell the agent: "Continue working on F-0005" with context.

### Pattern 3: Feature Planning (5 minutes)
```bash
# See what's planned
grep "Status: planned" spec/FEATURES.md

# Check dependencies
bash agentic/tools/feature_graph.sh

# See blockers
cat HUMAN_NEEDED.md
```
Now you know which features can be started.

### Pattern 4: Code Review Prep (3 minutes)
```bash
# Check what changed
tail -50 JOURNAL.md

# Verify docs updated
bash agentic/tools/verify.sh

# Check test coverage
bash agentic/tools/coverage.sh
```
Now you can review code with context.

## Common Questions → Commands

| Question | Command |
|----------|---------|
| What's the current focus? | `cat STATUS.md \| head -20` |
| What happened in last session? | `tail -30 JOURNAL.md` |
| How do I run tests? | `grep -i "test" STACK.md` |
| What features are done? | `grep "Status: shipped" spec/FEATURES.md` |
| What's blocking progress? | `cat HUMAN_NEEDED.md` |
| Is documentation current? | `bash agentic/tools/verify.sh` |
| Where is feature X implemented? | `grep -r "@feature F-000X" .` |
| What needs acceptance testing? | `bash agentic/tools/report.sh` |
| Are there broken references? | `bash agentic/tools/verify.sh` |
| What are the dependencies? | `bash agentic/tools/feature_graph.sh` |

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
   alias acheck='bash agentic/tools/doctor.sh'
   ```
3. **Use grep with color**: `grep --color=always ...` makes patterns visible
4. **Pipe to less**: `bash agentic/tools/report.sh | less` for long output
5. **Save outputs**: `bash agentic/tools/feature_graph.sh --save` creates docs/feature_graph.md

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
bash agentic/tools/doctor.sh | grep -E "(OK|Missing|Validation)" | head -10
echo ""
echo "▶ FEATURES SUMMARY"
bash agentic/tools/report.sh | head -10
echo ""
echo "▶ NEEDS ATTENTION"
grep -A 3 "^### HN-" HUMAN_NEEDED.md | head -15 || echo "None"
echo ""
echo "=== Ready to work! ==="
```

Save as `dashboard.sh` and run before each work session.

## Related Documentation

- Full tool documentation: `agentic/tools/` (each script has inline help)
- Token efficiency: `agentic/token_efficiency/reading_protocols.md`
- Agent workflows: `agentic/workflows/dev_loop.md`
- Quick start: `agentic/START_HERE.md`

