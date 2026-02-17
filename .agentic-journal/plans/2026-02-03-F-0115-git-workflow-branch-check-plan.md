# Plan: Git Workflow Branch Check (F-0115)

## Problem

The framework has `git_workflow` setting in STACK.md (`pull_request` vs `direct`) but:
1. **No enforcement** - setting is purely advisory
2. **Profile defaults not implemented** - both Core and Core+PM get `pull_request` hardcoded
3. **User never asked** their preference during init
4. **No branch warning** when committing on main/master with PR workflow

Risk: User with `git_workflow: pull_request` commits directly to main, bypassing review.

---

## User Insight

> "Some people might prefer working fast without PRs... i like that there is an option to use version control just with simple commits/pushes."

This is about **user choice**, not just profile enforcement. Options:
- Some users want rigor (PRs, review before merge)
- Some users want speed (direct commits, trust themselves)
- **Both are valid** - framework should respect the choice

---

## Proposed Solution

### 1. Add Branch Check to Pre-Commit (BLOCK with escape hatch)

Add to `pre-commit-check.sh`:
```bash
# Check 9/9: Branch policy for PR workflow
if git rev-parse --git-dir >/dev/null 2>&1; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  GIT_WORKFLOW=$(grep "git_workflow:" STACK.md 2>/dev/null | grep -oE "pull_request|direct" | head -1)

  if [[ "$GIT_WORKFLOW" == "pull_request" ]] && [[ "$CURRENT_BRANCH" =~ ^(main|master)$ ]]; then
    echo "❌ BLOCKED: Direct commit to $CURRENT_BRANCH with PR workflow"
    echo ""
    echo "   Your STACK.md has git_workflow: pull_request"
    echo "   This means you want changes reviewed before merging to main."
    echo ""
    echo "   Options:"
    echo "   1. Create a feature branch: git checkout -b feature/description"
    echo "   2. Hotfix bypass: git commit --no-verify (use sparingly)"
    echo "   3. Change workflow: Set git_workflow: direct in STACK.md"
    echo ""
    FAILURES=$((FAILURES + 1))
  fi
fi
```

**Key design choices:**
- **BLOCK** - PR workflow is a policy choice, not a soft signal
- **Built-in escape hatch** - `git commit --no-verify` for intentional hotfixes
- **Clear options** - tells user how to proceed legitimately
- **Respects STACK.md** - only blocks if `git_workflow: pull_request`
- **Users with `direct` workflow** - no block at all

### 2. Profile-Aware Workflow Selection

| Profile | Behavior |
|---------|----------|
| **Core+PM** | Default to `pull_request` (formal tracking = formal review) |
| **Core** | **ASK user** during init - they might want speed OR safety |

**Why ask for Core?** Core users are varied:
- Solo dev wanting speed → `direct`
- Solo dev wanting safety net → `pull_request`
- Small team without formal PM → could go either way

**Core+PM doesn't need to ask** - if you're doing formal specs/acceptance criteria, you probably want PR review too.

### 3. Add Git Workflow Question to Init (Core profile only)

Add to `init_playbook.md` after profile selection, **only for Core profile**:

```markdown
### Step 1c: Git Workflow (Core profile)

"How do you prefer to work with Git?"

a) **Direct commits** (default for Core - fast iteration)
   - Commit directly to main/master
   - No PR overhead
   - Good for: solo projects, prototypes, speed

b) **Pull Request workflow** (adds review step)
   - Create feature branches
   - Review changes before merging
   - Good for: safety net, audit trail, collaboration
```

### 4. Prominent STACK.md Comment

Update STACK.template.md to have a clear explanation:

```yaml
## Git workflow
<!-- How changes get into main branch -->
<!-- pull_request: Feature branches + PRs (review before merge) -->
<!-- direct: Commit straight to main (faster, less ceremony) -->
<!-- Pre-commit will WARN if committing to main with pull_request workflow -->
- git_workflow: direct  <!-- or pull_request -->
```

---

## Files to Modify

| File | Change | Lines |
|------|--------|-------|
| `.agentic/hooks/pre-commit-check.sh` | Add branch check (check 9/9) | ~15 |
| `.agentic/init/scaffold.sh` | Profile-aware: Core→direct, Core+PM→pull_request | ~5 |
| `.agentic/init/init_playbook.md` | Add git workflow question for Core profile only | ~20 |
| `.agentic/init/STACK.template.md` | Add prominent comment explaining git_workflow | ~5 |
| `spec/FEATURES.md` | Add F-0115 entry | ~20 |
| `spec/acceptance/F-0115.md` | Create acceptance criteria | ~25 |
| `tests/validate_framework.sh` | Add F-0115 tests | ~10 |

**Estimated total**: ~100 lines

---

## Verification

1. **Pre-commit branch check**:
   - With `git_workflow: pull_request` on main → should WARN
   - With `git_workflow: direct` on main → no warning

2. **Profile defaults**:
   - scaffold.sh with Core profile → should set `direct`
   - scaffold.sh with Core+PM profile → should set `pull_request`

3. **Init playbook**:
   - Core profile init → should ask about git workflow preference
   - Core+PM profile init → should NOT ask (defaults to pull_request)

4. **STACK.md comment**:
   - Verify prominent explanation of git_workflow options
   - Verify pre-commit warning is mentioned

5. Run `bash tests/validate_framework.sh`

---

## Design Rationale

| Principle | How Applied |
|-----------|-------------|
| **Warnings Beat Blocks for Soft Signals** | Scope drift, diff size = soft signals (WARN). Branch policy = hard rule (BLOCK). |
| **Make Human Review Efficient** | Clear error message with 3 options to proceed |
| **Instructions Don't Change Behavior** | Structural enforcement, not "remember to use PRs" |

**Why BLOCK not WARN for branch policy?**
- User explicitly chose `pull_request` workflow = they want enforcement
- Agents ignore warnings; they'll commit anyway
- This is policy violation, not judgment call
- Built-in escape hatch (`--no-verify`) for intentional hotfixes

The user can always:
- Use `git commit --no-verify` for hotfixes
- Change `git_workflow: direct` in STACK.md if they prefer speed
- Use `direct` workflow from the start (Core profile asks)
