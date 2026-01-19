# LLM Test Regression Guide

## The Problem

Adding instructions to fix one behavior can degrade others:
- **Attention drift**: More text = less focus on each part
- **Primacy/recency**: Items at top/bottom get more attention than middle
- **Cognitive load**: Long trigger tables get skimmed

## Rules for Guideline Changes

### 1. Budget Limits

| File | Max Lines | Current | Status |
|------|-----------|---------|--------|
| CLAUDE.md | 500 | ~500 | ⚠️ At limit |
| agent_operating_guidelines.md | 1200 | ~1200 | ⚠️ At limit |
| AGENT_QUICK_START.md | 100 | 81 | ✅ OK |
| Trigger table (rows) | 8 | 7 | ✅ OK |

**When at limit**: Remove/consolidate before adding.

### 2. Always Run Full Suite

```bash
# MANDATORY after ANY guideline change
bash tests/llm/harness.sh
```

**Never just run the test you're trying to fix.** Other tests may regress.

### 3. Test → Guideline Mapping

| Test | Primary Guideline Section | Secondary |
|------|---------------------------|-----------|
| 001_session_start | Session Start Protocol | Proactive greeting |
| 002_wip_blocks_commit | before_commit trigger | WIP handling |
| 003_acceptance_first | Feature trigger row | BLOCKING GATE |
| 004_uses_journal_script | Journal trigger row | Token-efficient scripts |
| 005_no_auto_commit | Git workflow section | Never auto-commit |
| 006_wip_recovery | Session Start Protocol | WIP handling |
| 007_small_batch | Large task trigger row | Small Batch section |
| 008_reads_context_pack | Project question trigger | Core Guidelines |
| 009_mentions_checklist | Checklist references | Feature Complete |
| 010_feature_needs_spec | Feature trigger row | BLOCKING GATE |

### 4. Before Making Guideline Changes

Ask yourself:
1. **Can I consolidate instead of add?** Merge similar triggers
2. **Can I shorten existing text?** Remove redundant explanations
3. **Is this at TOP or BOTTOM?** Critical items need primacy/recency
4. **What tests might regress?** Check mapping above
5. **Am I at budget limit?** If yes, remove something first

### 5. After Making Changes

```bash
# 1. Run FULL test suite (not just target test)
bash tests/llm/harness.sh

# 2. If any test fails that wasn't failing before:
#    - You caused a regression
#    - Either revert or fix both issues

# 3. Record baseline
echo "$(date): 10/10 passing after [change description]" >> tests/llm/test-history.log
```

## Consolidation Opportunities

Current trigger table has some overlap:

```
| "build", "implement", "add", "create"... | → check acceptance |
| "implement entire", "full system"...     | → too big, break down |
```

These could potentially merge:
```
| "implement", "build", "add", "create" | → Check acceptance. If "entire/full/complete system" → break down first |
```

**Trade-off**: Shorter table vs. less explicit triggers.

## Test History

Track pass rates over time to detect gradual degradation:

```
# After each change, log results
echo "$(date +%Y-%m-%d) | v$(cat VERSION) | [change] | X/10" >> tests/llm/test-history.log
```

## Warning Signs

- Pass rate drops below 80% → Investigate immediately
- Same test becomes flaky (passes sometimes) → Guideline is ambiguous
- File size exceeds budget → Consolidate before adding more
