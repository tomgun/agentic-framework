---
feature: F-0203
title: "Auto-Commit/Merge Mode (R2 Amendment)"
status: APPROVED
created: 2026-03-12
revision: 3
review_history: |
  R1 (2026-03-12): Critic REQUEST_CHANGES, Advocate APPROVE
  Key revision: CriticalAgent.review_commit() dedicated method (Critic Issue #1),
  return value disambiguation (Issue #2), error recovery hardening (Issue #3),
  explicit _check_and_update_docs() code (Issue #5), expanded test coverage (Issue #7)
  R2 (2026-03-12): Critic REQUEST_CHANGES (2 HIGH doc gaps), Advocate APPROVE
  R3 fix: Focus entry wording, template verification step, error semantics docs, cross-AC note
---

# F-0203: Auto-Commit/Merge Mode (R2 Amendment) — Implementation Plan (R2)

## Context

ADR-002 §4 defines a **R2 amendment**: adding `review_commit: human | critical_agent` setting that distinguishes interactive sessions (never auto-commit) from automated execution (critical agent reviews diff, auto-commits if approved). This formalizes a known violation in `task.py._commit_ac()` (line 341-361) which currently auto-commits without any review. The amendment preserves R2 for the 99% case (interactive sessions) while enabling Mode 3 (Fully Autonomous) workflows.

## Design Decisions

1. **`review_commit` is a behavioral permission, NOT a state transition review.** It controls whether `task.py._commit_ac()` can execute `git commit`. It does NOT go into `review.py:TRANSITION_REVIEW_MAP` or `check_review()`. Those are for feature lifecycle state transitions. `review_commit` is read directly via `get_setting()` in task.py. **Because it's not a state transition, it uses a dedicated `CriticalAgent.review_commit()` method** — not the generic `review()` method which assembles full feature-transition context. This avoids overloading the state transition interface and keeps commit reviews lightweight (staged diff + AC only, per F3 Token Optimization).

2. **Two valid values only: `human` | `critical_agent`.** No `skip` — committing is a destructive action that must have either human or agent oversight. Unrecognized values fall back to `human` (safe default).

3. **Per-AC review scope.** CriticalAgent reviews each AC's staged diff individually (matching the existing `_commit_ac()` call pattern at line 178). Smaller diffs are easier to evaluate and allow early-halt on rejection.

4. **Both auto-commit call sites gated.** `task.py` has TWO auto-commit points: `_commit_ac()` (line 341) and `_check_and_update_docs()` (line 322). Both must respect `review_commit`. The `_check_and_update_docs()` commit preserves its existing `git add -u` behavior (tracked files only) to avoid accidentally staging unrelated new files.

5. **Profile defaults:** discovery=`human`, formal=`human`, autonomous_formal=`critical_agent`. Only autonomous_formal enables auto-commit, which aligns with ADR-002 Mode 3. If a user explicitly sets `review_commit: critical_agent` in a different profile, we respect their choice — the setting is validated at the code level, not the profile level.

6. **Instruction file amendment language** (improved per review):
   > In interactive development sessions, agents never commit without explicit approval. In autonomous workflows (`ag auto task`, `ag auto epic`) with `review_commit: critical_agent`, agents commit after adversarial AI review.

   This is more specific about what "interactive" and "autonomous" mean.

7. **Return value semantics.** `_commit_ac()` returns `bool` where `True` = committed, `False` = not committed (for any reason). To disambiguate the caller's perspective, we also print a message explaining the outcome. The caller (`run()` at line 178) records `ac_result.committed` — in human mode, `committed=False` is expected behavior (changes staged for human review), not an error. The `TaskResult.to_dict()` output already includes per-AC status, which gives sufficient observability.

## Acceptance Criteria

- AC-001: `review_commit` setting resolves via 3-level settings chain (STACK.md → profile → default `human`)
- AC-002: `_commit_ac()` with `review_commit: human` stages files but does NOT commit; returns `False`
- AC-003: `_commit_ac()` with `review_commit: critical_agent` spawns CriticalAgent, commits if approved, returns `True`; if rejected, does NOT commit, returns `False`
- AC-004: `_check_and_update_docs()` also respects `review_commit` setting (preserves `git add -u` for tracked files only)
- AC-005: Profile defaults: discovery=`human`, formal=`human`, autonomous_formal=`critical_agent`
- AC-006: `review_commit` appears in STACK.template.md, STACK.md (framework's own), profiles.conf
- AC-007: PRINCIPLES.md R2 amended with conditional language
- AC-008: All instruction files with "Never auto-commit" amended (14 files)
- AC-009: LLM test 005 documents conditional behavior
- AC-010: `validate_framework.sh` has F-0203 tests
- AC-011: memory-seed.md updated with amended rule + sentinel
- AC-012: `critical_agent.py` has dedicated `review_commit()` method with `review_commit` focus entry

## Implementation Steps

### Step 1: Acceptance Criteria File

**Create** `.agentic/spec/acceptance/F-0203.md` with the above criteria.

### Step 2: Core Implementation — task.py

**Modify** `.agentic/lib/auto/task.py`

Add import at top (after existing `from settings` import in `_check_and_update_docs`, or consolidate):
```python
from settings import get_setting
```

**`_commit_ac()` (lines 341-361) — replace entirely:**
```python
def _commit_ac(
    self, feature_id: str, ac_id: str, ac_text: str
) -> bool:
    """Commit current changes for a passing AC (respects review_commit).

    Returns True if changes were committed, False otherwise.
    With review_commit: human, stages only (returns False — expected behavior).
    With review_commit: critical_agent, commits after adversarial review.
    """
    review_commit = get_setting(self.project_root, "review_commit", "human")

    # Always stage changes
    try:
        subprocess.run(
            ["git", "add", "-A"],
            cwd=str(self.project_root),
            capture_output=True,
            check=True,
        )
    except subprocess.CalledProcessError:
        return False

    if review_commit != "critical_agent":
        # human (default) — stage only, don't commit
        print(f"  Changes staged for {ac_id}. Commit skipped (review_commit: human).")
        return False

    # critical_agent mode — adversarial review then commit
    from auto.critical_agent import CriticalAgent

    agent = CriticalAgent(self.project_root)
    try:
        verdict = agent.review_commit(feature_id, ac_id, ac_text)
    except Exception as e:
        print(f"  Critical agent error: {e}. Unstaging.", file=sys.stderr)
        self._unstage_or_warn()
        return False

    if verdict.verdict != "approved":
        print(
            f"  Critical agent rejected commit for {ac_id}: {verdict.summary}",
            file=sys.stderr,
        )
        self._unstage_or_warn()
        return False

    # Approved — commit
    message = f"feat({feature_id}): implement {ac_id} — {ac_text[:60]}"
    try:
        subprocess.run(
            ["git", "commit", "-m", message],
            cwd=str(self.project_root),
            capture_output=True,
            check=True,
        )
        return True
    except subprocess.CalledProcessError:
        return False
```

**Add helper `_unstage_or_warn()` (new method):**
```python
def _unstage_or_warn(self) -> None:
    """Unstage all files. Warn if unstaging fails."""
    result = subprocess.run(
        ["git", "reset", "HEAD"],
        cwd=str(self.project_root),
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(
            f"  WARNING: git reset HEAD failed ({result.returncode}). "
            f"Files may remain staged. Run 'git reset HEAD' manually.",
            file=sys.stderr,
        )
```

**`_check_and_update_docs()` (lines 322-339) — replace the commit block:**

Current code (lines 322-339):
```python
        # Commit doc updates separately (only modified tracked files)
        try:
            subprocess.run(
                ["git", "add", "-u"],
                ...
            )
            subprocess.run(
                ["git", "commit", "-m", ...],
                ...
            )
            print("  Documentation updates committed")
        except subprocess.CalledProcessError:
            pass  # No changes to commit
```

Replace with:
```python
        # Stage doc updates (tracked files only — preserves existing git add -u)
        try:
            subprocess.run(
                ["git", "add", "-u"],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
        except subprocess.CalledProcessError:
            return  # Nothing to stage

        review_commit = get_setting(self.project_root, "review_commit", "human")
        if review_commit != "critical_agent":
            print(f"  Doc updates staged. Commit skipped (review_commit: human).")
            return

        # critical_agent mode — review doc changes before committing
        from auto.critical_agent import CriticalAgent

        agent = CriticalAgent(self.project_root)
        try:
            verdict = agent.review_commit(feature_id, "docs", "documentation updates")
        except Exception as e:
            print(f"  Critical agent error on docs: {e}. Unstaging.", file=sys.stderr)
            self._unstage_or_warn()
            return

        if verdict.verdict != "approved":
            print(f"  Critical agent rejected doc commit: {verdict.summary}", file=sys.stderr)
            self._unstage_or_warn()
            return

        try:
            subprocess.run(
                ["git", "commit", "-m",
                 f"docs({feature_id}): update documentation for feature"],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
            print("  Documentation updates committed")
        except subprocess.CalledProcessError:
            pass  # No changes to commit
```

### Step 3: CriticalAgent — Dedicated `review_commit()` Method

**Modify** `.agentic/lib/auto/critical_agent.py`

Add to `_REVIEW_FOCUS` dict (after `review_taste`, line 80):
```python
"review_commit": (
    "Focus on: does the staged diff satisfy the acceptance criterion? "
    "Check for: AC requirement alignment, secrets or credentials in diff, "
    "unintended file additions/deletions, scope creep beyond this AC, "
    "code correctness, breaking changes to other features, "
    "no regression indicators. (Tests already passed before this review.)"
),
```

Add new public method to `CriticalAgent` class (after `review()`):
```python
def review_commit(
    self,
    feature_id: str,
    ac_id: str,
    ac_text: str,
) -> ReviewVerdict:
    """Review a staged diff for a single AC before auto-commit.

    Unlike review() which handles state transitions with full feature context,
    this method is lightweight: only the staged diff + the specific AC.
    Designed for per-AC commit review in automated execution (F-0203).

    On transient errors, retries once before raising.
    On timeout/unavailable, raises immediately (caller falls back to human).

    Error semantics for callers:
    - RuntimeError raised → caller should unstage and return False
    - verdict="escalate" returned → treated same as rejection (unstage, return False)
    - verdict="request_changes" → treated same as rejection
    - Only verdict="approved" results in a commit
    """
    context = self._assemble_commit_context(feature_id, ac_id, ac_text)
    prompt = self._build_prompt(context, "review_commit")
    model = self._resolve_model()

    # First attempt
    output = spawn_claude(
        self.claude_command, self.project_root, prompt,
        print_mode=True, timeout=_REVIEW_TIMEOUT, model=model,
    )

    if self._is_error(output):
        error_type = self._classify_error(output)
        if error_type == "transient":
            time.sleep(_RETRY_DELAY)
            output = spawn_claude(
                self.claude_command, self.project_root, prompt,
                print_mode=True, timeout=_REVIEW_TIMEOUT, model=model,
            )
            if self._is_error(output):
                raise RuntimeError(
                    f"Critical agent commit review failed after retry: {output[:200]}"
                )
        else:
            raise RuntimeError(
                f"Critical agent commit review {error_type}: {output[:200]}"
            )

    return self._parse_verdict(output)

def _assemble_commit_context(
    self,
    feature_id: str,
    ac_id: str,
    ac_text: str,
) -> str:
    """Assemble minimal context for commit review (F3-optimized).

    Only includes: the AC being implemented + the staged diff.
    Does NOT load full feature spec or all ACs (unlike _assemble_context).
    """
    sections: list[str] = []

    sections.append(
        f"## Commit Review\n"
        f"Feature: {feature_id}, AC: {ac_id}\n"
        f"Criterion: {ac_text}"
    )

    # Staged diff only (not full branch diff)
    try:
        diff_result = subprocess.run(
            ["git", "diff", "--cached"],
            cwd=str(self.project_root),
            capture_output=True,
            text=True,
        )
        if diff_result.returncode == 0 and diff_result.stdout.strip():
            diff = self._truncate_diff(diff_result.stdout)
            sections.append(f"## Staged Changes\n```diff\n{diff}\n```")
        else:
            sections.append("## Staged Changes\nNo staged changes detected.")
    except (FileNotFoundError, OSError):
        sections.append("## Staged Changes\nUnable to read staged diff.")

    return "\n\n".join(sections)
```

### Step 4: Profile Configuration

**Modify** `.agentic/lib/presets/profiles.conf`

Add after each profile's existing last setting line:
```
discovery.review_commit=human
formal.review_commit=human
autonomous_formal.review_commit=critical_agent
```

Place each one after the corresponding profile's `kickoff_confirm` line (last existing setting per profile).

### Step 5: STACK.template.md

**Modify** `.agentic/lib/init/STACK.template.md`

Add after `review_taste` line (line 89), before `kickoff_confirm`:
```markdown
- review_commit: human
# Auto-commit permission for automated execution (`ag auto task/epic`). human: stage only, human reviews (default) | critical_agent: adversarial AI review then auto-commit. Discovery: human | Formal: human | Autonomous Formal: critical_agent
```

### Step 6: Framework's Own STACK.md

**Modify** `STACK.md` — add `review_commit: human` to Review checkpoints section, after `review_taste`:
```markdown
- review_commit: human
# Auto-commit in automated execution. human: stage only (default) | critical_agent: adversarial review then commit. Discovery: human | Formal: human | Autonomous Formal: critical_agent
```

### Step 7: PRINCIPLES.md R2 Amendment

**Modify** `.agentic/lib/PRINCIPLES.md` (lines 341-355)

Change R2 title from:
> ### R2. No Auto-Commits Without Approval

To:
> ### R2. No Auto-Commits Without Approval (Conditional)

Change **What** from:
> **What**: Agents NEVER commit changes without explicit human approval.

To:
> **What**: In interactive development sessions, agents NEVER commit changes without explicit human approval. In autonomous workflows (`ag auto task`, `ag auto epic`), agents may commit after adversarial review by the critical agent, when explicitly opted-in via `review_commit: critical_agent` (F-0203).

Update **Enforcement** to:
> **Enforcement**: Behavioral — LLM test (LLM-005) verifies interactive sessions comply. Structural — `task.py._commit_ac()` checks `review_commit` setting; `CriticalAgent.review_commit()` evaluates every staged diff.

Update **Exception** to:
> **Exception**: User may grant blanket approval for a session. Automated execution may auto-commit when `review_commit: critical_agent` — critical agent evaluates every diff before commit (F-0203).

### Step 8: core-rules.md

**Modify** `.agentic/lib/agents/shared/guidelines/core-rules.md`

From: `2. **Never auto-commit** without explicit human approval. Show changes first.`
To: `2. **Never auto-commit** in interactive sessions without explicit human approval. Show changes first. (Autonomous workflows with `review_commit: critical_agent` may commit after adversarial review — F-0203.)`

### Step 9: Instruction File Sync (14 files)

All files containing "Never auto-commit" get the same amendment. Two wording variants:

**Long form** (for docs, guidelines, principles — already covered in Steps 7, 8, 10, 11):
> In interactive development sessions, agents never commit without explicit approval. In autonomous workflows (`ag auto task`, `ag auto epic`) with `review_commit: critical_agent`, agents commit after adversarial AI review (F-0203).

**Short form** (for templates/root files with one-line rules):
> Never auto-commit in interactive sessions. Show changes to human first. (Autonomous workflows use `review_commit` setting — F-0203.)

**Files using short form:**
1. `CLAUDE.md` (root)
2. `.agentic/lib/agents/claude/CLAUDE.md` (template)
3. `.agentic/lib/agents/cursor/cursorrules.txt`
4. `.agentic/lib/agents/copilot/copilot-instructions.md`
5. `.agentic/lib/agents/codex/codex-instructions.md`
6. `.github/copilot-instructions.md`
7. `.cursorrules`
8. `.codex/instructions.md`
9. `CODEX.md`
10. `.agentic/lib/DEVELOPER_GUIDE.md` (settings reference section gets expanded explanation)
11. `.agentic/lib/agents/claude/skills/committing-changes/SKILL.md`
12. `.claude/skills/committing-changes/SKILL.md`

**Already covered by other steps:**
13. `.agentic/lib/agents/shared/guidelines/core-rules.md` (Step 8)
14. `.agentic/lib/init/memory-seed.md` (Step 10)

### Step 10: memory-seed.md

**Modify** `.agentic/lib/init/memory-seed.md`

In "Rules that always apply" section, change:
> **Never auto-commit.** Human reviews every change first.

To:
> **Never auto-commit in interactive sessions.** Human reviews every change first. Autonomous workflows (`ag auto task/epic`) may commit when `review_commit: critical_agent` (F-0203).

Bump version marker (e.g., `v0.53.6` → `v0.54.0`).
Add `review_commit` to the sentinel keywords list (the `# sentinels:` comment at top of the rules section).

### Step 11: agent_operating_guidelines.md

Add `review_commit` row to GATES table:
```
| review_commit | human \| critical_agent | human | Auto-commit in ag auto task/epic. critical_agent: adversarial review then commit |
```

Amend "Never commit without approval" in Agent Boundaries section to include conditional language matching Step 8.

### Step 12: Tests

**validate_framework.sh** — Add F-0203 section:
- `review_commit` exists in profiles.conf (all 3 profiles)
- `review_commit` exists in STACK.template.md
- `task.py` references `review_commit`
- `critical_agent.py` has `review_commit` method AND focus entry
- `PRINCIPLES.md` has "interactive" + "autonomous" language in R2

**005_no_auto_commit.sh** — Add comments documenting this tests `review_commit: human` behavior (discovery default). No behavioral change needed since discovery defaults to `human`.

**test_definitions.json** — Update test 005 description to mention `review_commit`.

**test_auto_task.py** — Add tests:
- `test_commit_ac_human_mode_stages_only`: verify git add called, git commit NOT called, returns False
- `test_commit_ac_critical_agent_approved`: verify CriticalAgent.review_commit() called with (feature_id, ac_id, ac_text), git commit on approval, returns True
- `test_commit_ac_critical_agent_rejected`: verify review_commit() called, no commit on rejection, unstage called, returns False
- `test_commit_ac_critical_agent_timeout`: verify exception from review_commit() triggers unstage, returns False
- `test_commit_ac_staging_fails`: verify early return False before any agent call
- `test_commit_ac_unstage_failure_warns`: verify _unstage_or_warn() prints warning when git reset fails
- `test_check_docs_human_mode_stages_only`: verify doc updates staged but not committed in human mode
- `test_check_docs_critical_agent_approved`: verify doc commit after approval

### Step 13: Documentation

**HOW_IT_WORKS.md** — Add `review_commit` subsection explaining:
- The two modes (human vs. critical_agent)
- Relationship to R2 principle
- Why `review_commit()` is separate from `review()` (commit review ≠ state transition)
- Expected latency: ~30-60s per AC review in critical_agent mode

**DEVELOPER_GUIDE.md** — Add `review_commit` to settings reference with:
- Values: `human` (default) | `critical_agent`
- Profile defaults
- When to use: only in `autonomous_formal` profile or explicit opt-in for autonomous workflows
- Performance note: adds ~30-60s per AC for adversarial review
- Fallback behavior: unrecognized values silently fall back to `human` (safe default)
- Cross-AC note: per-AC reviews assume the test suite catches cross-AC invariant violations. If your test suite is weak, per-AC auto-commit has a gap — the full verify loop and human review_merge are your safety nets.

## Execution Order

### Phase 1: Foundation (do first)
- AC-001, AC-005, AC-006: Settings infrastructure (profiles.conf, STACK.template.md, STACK.md)
- AC-012: CriticalAgent `review_commit()` method + focus entry
- Verify: `critical_review.md` template works with minimal commit context (only AC + staged diff, no full feature spec). The template uses `{context}`, `{focus}`, `{verdict_schema}` placeholders — confirm all three are populated correctly by `_build_prompt()` when called with `review_commit` setting.

### Phase 2: Core Logic (P1 — MVP)
- AC-002, AC-003, AC-004: task.py conditional behavior (depends on Phase 1)
CHECKPOINT: Run `python3 -m pytest tests/test_auto_task.py -v`

### Phase 3: Principle Amendment
- AC-007: PRINCIPLES.md R2
- AC-008 [P]: Instruction file sync (14 files, parallelizable in 2 batches)
- AC-011: memory-seed.md
CHECKPOINT: `bash tests/validate_framework.sh`

### Phase 4: Tests + Docs
- AC-009, AC-010: Test updates
- Documentation updates

## Commit Strategy (5 commits, max 10 files each)

| # | Message | Files | Count |
|---|---------|-------|-------|
| 1 | `feat(F-0203): add review_commit setting + task.py/critical_agent logic` | AC file, task.py, critical_agent.py, profiles.conf, STACK.template.md, STACK.md | 6 |
| 2 | `docs(F-0203): amend R2 principle and shared guidelines` | PRINCIPLES.md, core-rules.md, agent_operating_guidelines.md, memory-seed.md | 4 |
| 3 | `docs(F-0203): sync template instruction files with R2 amendment` | 5 template files (claude CLAUDE.md, cursorrules.txt, copilot, codex, committing-changes SKILL.md) | 5 |
| 4 | `docs(F-0203): sync root instruction files with R2 amendment` | CLAUDE.md, .cursorrules, .github/copilot, .codex/instructions, CODEX.md, .claude/skills/committing-changes, DEVELOPER_GUIDE.md | 7 |
| 5 | `test(F-0203): framework validation, LLM test update, unit tests, docs` | validate_framework.sh, 005_no_auto_commit.sh, test_definitions.json, test_auto_task.py, HOW_IT_WORKS.md | 5 |

## Critical Files

| File | Lines | What Changes |
|------|-------|--------------|
| `.agentic/lib/auto/task.py` | 341-361, 322-339 | `_commit_ac()` + `_check_and_update_docs()` conditional on `review_commit` + `_unstage_or_warn()` helper |
| `.agentic/lib/auto/critical_agent.py` | 50-80, new methods | `review_commit()` method + `_assemble_commit_context()` + focus entry |
| `.agentic/lib/presets/profiles.conf` | after kickoff_confirm | Add `review_commit` to all 3 profiles |
| `.agentic/lib/PRINCIPLES.md` | 341-355 | R2 amendment — the constitutional change |
| `.agentic/lib/agents/shared/guidelines/core-rules.md` | 16 | Conditional language for rule 2 |
| `tests/test_auto_task.py` | new section | 8 unit tests for conditional commit behavior |

## Risks

1. **CriticalAgent latency per AC**: Each AC triggers agent review (~30-60s). For 10 ACs, that's ~5-10 minutes. Acceptable for autonomous_formal (unattended). Documented in DEVELOPER_GUIDE.md.
2. **Two auto-commit call sites**: Must not miss `_check_and_update_docs()`. Plan explicitly covers both with full code shown.
3. **Unrecognized setting values**: Guard with `!= "critical_agent"` check (anything that isn't explicitly critical_agent falls through to human).
4. **14-file instruction sync**: Tedious but mechanical. Post-implementation grep verification ensures consistency.
5. **git reset failure after agent rejection**: Mitigated by `_unstage_or_warn()` helper that logs a clear warning with manual recovery instructions.
6. **CriticalAgent review quality**: If agent consistently misses issues, bad code gets committed. Mitigated by: (a) test suite must pass before `_commit_ac()` is called, (b) PR still requires human review_merge, (c) per-AC granularity limits blast radius.

## Revision Guidance (from R1 Review)

Changes from R1 → R2:
- **NEW**: Dedicated `CriticalAgent.review_commit()` method instead of reusing `review()`. Avoids state-transition interface mismatch and reduces token waste (only staged diff + AC, not full feature context).
- **NEW**: `_assemble_commit_context()` builds minimal context (staged diff + single AC). Aligns with F3 Token Optimization.
- **NEW**: `_unstage_or_warn()` helper for robust error recovery when `git reset HEAD` fails.
- **CHANGED**: `_check_and_update_docs()` now shows explicit implementation (not "same pattern" hand-wave). Preserves `git add -u` (tracked files only).
- **CHANGED**: Instruction file language improved per Critic feedback — specifies "interactive development sessions" and "autonomous workflows" instead of vague "interactive sessions".
- **CHANGED**: Focus entry expanded to include file scope changes, breaking changes.
- **ADDED**: 3 additional test cases (timeout, staging failure, unstage failure).
- **ADDED**: Design Decision #7 clarifying return value semantics.
- **ADDED**: Performance expectations documented in DEVELOPER_GUIDE.md scope (Step 13).

## Verification

1. `python3 -m pytest tests/test_auto_task.py -v` — 8 unit tests for conditional commit
2. `bash tests/validate_framework.sh` — F-0203 structural tests pass
3. `grep -r "Never auto-commit" --include="*.md" --include="*.txt"` — verify all active files amended
4. `grep "review_commit" .agentic/lib/presets/profiles.conf` — 3 entries
5. `grep "review_commit" .agentic/lib/auto/critical_agent.py` — method + focus entry
6. Manual: Set `review_commit: critical_agent` in STACK.md, run `ag auto task F-test` on a scratch project
