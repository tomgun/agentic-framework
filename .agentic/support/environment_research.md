# AI Environment Research

**Purpose**: Track capabilities and optimal practices for each AI coding environment.

**Last updated**: 2026-01-06  
**Framework version**: 0.4.3

---

## Environment Capabilities Matrix

| Feature | Claude Code | Cursor | GitHub Copilot |
|---------|----------------|--------|----------------|
| **Instruction File** | `CLAUDE.md` (root) | `.cursor/rules/*.mdc` or `.cursorrules` | `.github/copilot-instructions.md` |
| **Context Window** | 200K tokens | Varies by model | ~8K tokens (limited) |
| **Project Context** | Automatic (all files) | Selective (@ mentions) | Limited (open files) |
| **Hooks/Lifecycle** | ✅ Yes (SessionStart, PostToolUse, PreCompact, Stop) | ❌ No | ❌ No |
| **File Operations** | Direct file edits | Direct file edits | Suggestions only (user applies) |
| **Terminal Access** | ✅ Yes (can run commands) | ✅ Yes (via composer) | ❌ No (chat only) |
| **Multi-file Edits** | ✅ Yes (batch edits) | ✅ Yes (composer) | ⚠️ Limited (one at a time) |
| **Project-wide Search** | ✅ Yes | ✅ Yes (via @ search) | ❌ No |
| **Artifacts** | ✅ Yes (can create docs, diagrams) | ❌ No | ❌ No |
| **Memory/Context** | Session-based | Conversation-based | Minimal (per-file) |

---

## Environment-Specific Optimizations

### Claude Code

**Strengths:**
- Lifecycle hooks (automatic checkpoint logging!)
- Large context window (can hold entire project)
- Direct file operations
- Terminal access
- Artifacts for documentation

**Optimal setup:**
1. Use hooks for automatic logging:
   - `SessionStart.sh` → Load context
   - `PostToolUse.sh` → Quick checks
   - `PreCompact.sh` → Auto-log before context reset
   - `Stop.sh` → Session end reminder

2. Leverage large context:
   - Can read entire FEATURES.md at once
   - Can process all specs simultaneously
   - Less need for token-efficient scripts (but still recommended)

3. Use artifacts for:
   - Architecture diagrams
   - Documentation drafts
   - Planning sessions

**Instructions location**: `CLAUDE.md` in project root

**Recommended `.agentic/claude-hooks/hooks.json`**:
```json
{
  "hooks": {
    "SessionStart": {
      "command": "bash .agentic/claude-hooks/SessionStart.sh",
      "timeout": 5000
    },
    "PostToolUse": {
      "command": "bash .agentic/claude-hooks/PostToolUse.sh",
      "timeout": 2000
    },
    "PreCompact": {
      "command": "bash .agentic/claude-hooks/PreCompact.sh",
      "timeout": 10000
    },
    "Stop": {
      "command": "bash .agentic/claude-hooks/Stop.sh",
      "timeout": 5000
    }
  }
}
```

---

### Cursor

**Strengths:**
- Integrated IDE (sees all open files)
- Composer mode (multi-file edits)
- @ mentions for precise context
- Terminal access via composer
- Agentic mode (autonomous task execution)

**Limitations:**
- No lifecycle hooks
- Smaller context window than Claude
- Instructions must be in `.cursor/rules/*.mdc` or `.cursorrules`

**Optimal setup:**
1. Use `.cursor/rules/agentic-framework.mdc` for instructions
   - Modern approach (Cursor 0.42+)
   - Better organization than `.cursorrules`

2. Leverage @ mentions:
   - `@FEATURES.md` to load specific doc
   - `@Codebase` for project-wide search
   - `@Files` for multi-file context

3. Use composer mode for:
   - Multi-file refactors
   - Feature implementations across files
   - Terminal commands + file edits

4. Use token-efficient scripts:
   - Cursor has smaller context than Claude
   - Scripts save significant tokens

**Instructions location**: `.cursor/rules/agentic-framework.mdc`

**Recommended additions to instructions**:
```markdown
## Cursor-Specific Tips

1. **Use @ mentions for precise context**:
   - @FEATURES.md for feature list
   - @Codebase "search term" for project-wide search
   - @Files src/auth/*.ts for bulk context

2. **Leverage composer mode**:
   - Multi-file edits in one shot
   - Terminal + file edits together
   - Ask for "composer mode" if you need to edit 3+ files

3. **Check agentic mode**:
   - If user enables agentic mode, you can work more autonomously
   - Still follow session_start/end protocols
```

---

### GitHub Copilot

**Strengths:**
- Integrated in VS Code/GitHub
- Excellent inline suggestions
- Chat interface in IDE
- Works in browser (github.dev)

**Limitations:**
- VERY small context window (~8K tokens)
- No file operations (suggestions only, user must apply)
- No terminal access
- No project-wide operations
- Limited to open files

**Optimal setup:**
1. Instructions MUST be minimal (8K limit!):
   - Keep `.github/copilot-instructions.md` concise
   - Point to external docs heavily
   - Use AGENTS.md as lightweight summary

2. Token-efficient scripts are CRITICAL:
   - Copilot can't afford to read whole files
   - Every script call saves massive tokens
   - Prioritize scripts over file edits

3. Work file-by-file:
   - Can't do multi-file refactors easily
   - Focus on one component at a time
   - Break work into small chunks

4. Rely on user for:
   - File operations (user must apply suggestions)
   - Terminal commands (user must run)
   - Multi-file context (user must open files)

**Instructions location**: `.github/copilot-instructions.md`

**Recommended ULTRA-CONCISE instructions**:
```markdown
# GitHub Copilot Instructions

This repo uses Agentic Framework (`.agentic/`).

**CRITICAL**: Context window is TINY (~8K tokens). Be ruthlessly efficient.

## Start Every Session
1. Read `AGENTS.md` (summary of rules)
2. Check `HUMAN_NEEDED.md` (blockers)
3. Use scripts (NOT file edits):
   ```bash
   bash .agentic/tools/journal.sh "Topic" "Done" "Next" "Blockers"
   bash .agentic/tools/feature.sh F-#### status shipped
   ```

## Rules
- **Tests required** (`.agentic/quality/test_strategy.md`)
- **Docs = part of done** (update docs when code changes)
- **Use scripts** (token-efficient, 40x cheaper than file edits)

## Checklists
- Before work: `.agentic/checklists/session_start.md`
- After work: `.agentic/checklists/session_end.md`
- Before "done": `.agentic/checklists/feature_complete.md`

Full details: `.agentic/agents/shared/agent_operating_guidelines.md`
```

---

## Framework Age Check (Staleness Detection)

**Problem**: AI tool capabilities evolve rapidly. Framework instructions may become outdated.

**Solution**: Check framework age at init, offer research if old.

**Thresholds**:
- <1 month: No warning (framework is current)
- 1-3 months: Suggest optional research
- >3 months: Strongly recommend research

**Implementation** (in `init_playbook.md`):

```bash
# Check framework age
FRAMEWORK_VERSION=$(cat .agentic/../VERSION 2>/dev/null || echo "unknown")
FRAMEWORK_DATE=$(git -C .agentic log -1 --format=%cd --date=short 2>/dev/null || echo "unknown")
DAYS_OLD=$(( ($(date +%s) - $(date -d "$FRAMEWORK_DATE" +%s 2>/dev/null || echo 0)) / 86400 ))

if [[ $DAYS_OLD -gt 90 ]]; then
  echo "⚠️  Framework is >3 months old. AI tool capabilities may have changed."
  echo "Recommend: Research current best practices for [Claude/Cursor/Copilot]"
elif [[ $DAYS_OLD -gt 30 ]]; then
  echo "ℹ️  Framework is >1 month old. Consider researching latest AI tool features."
fi
```

**Research prompts** (offer to user):

```markdown
## Optional: Research Latest AI Tool Capabilities

The Agentic Framework was last updated ${DAYS_OLD} days ago.
AI coding tools evolve rapidly. Would you like to research current best practices?

**Research topics:**
1. **Claude Code updates** (hooks, context window, new features)
2. **Cursor updates** (agentic mode, composer improvements, @ mentions)
3. **Copilot updates** (context window, new capabilities, workspaces)

**Recommended if:**
- Using tool features not documented in framework
- Framework feels outdated for your environment
- Tool released major update recently

**To research**: Ask agent to research "[Tool] latest features and best practices"
and update `.agentic/support/environment_research.md`
```

---

## Keeping This Document Current

**Update when**:
- Major AI tool update (new features, changed capabilities)
- Framework adds environment-specific features
- Community discovers better practices
- Every 3-6 months (maintenance review)

**How to update**:
1. Research current tool capabilities (official docs, changelogs)
2. Test features in each environment
3. Update matrix and optimization sections
4. Update framework version/date at top
5. Commit with clear changelog

**Template for updates**:
```markdown
### YYYY-MM-DD Update

**Tool updates**:
- Claude Code 1.X: Added [feature], improved [capability]
- Cursor 0.X: New [feature], changed [behavior]
- Copilot: Increased context to XK tokens, added [feature]

**Framework adaptations**:
- Updated Claude instructions to leverage [new feature]
- Added Cursor-specific optimization for [capability]
- Reduced Copilot instructions due to [constraint]

**Breaking changes**: [if any]
```

---

## Summary

**Key differences**:
1. **Claude**: Large context, hooks, autonomous → Use hooks, leverage context
2. **Cursor**: IDE-integrated, @ mentions, composer → Use @ mentions, composer mode
3. **Copilot**: Tiny context, suggestions-only → Ultra-concise, scripts critical

**Framework strategy**:
- Shared core (`.agentic/agents/shared/`)
- Environment-specific optimizations (separate instruction files)
- Token efficiency for ALL (but critical for Copilot)
- Hooks for Claude only (unique capability)

**Maintenance**:
- Check framework age at init (>30 days = consider research)
- Update this doc every 3-6 months
- Test changes in all three environments

