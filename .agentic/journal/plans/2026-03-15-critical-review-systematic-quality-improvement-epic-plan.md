# Critical Review: Systematic Quality Improvement Epic

## Overall Assessment

The plan correctly identifies the core problem: detection exists but enforcement doesn't bite. The phasing is mostly right, the scope is contained, and it stays focused on user-project value. But Phase 1 is over-engineered relative to its impact, and Phase 4 has a viability problem.

---

## Phase 1: NFR->AC Integration — Over-Engineered

### What's Good
- Moving NFR constraints INTO the AC list (not a separate section) is the right structural move. Agents actually read ACs during implementation; they ignore `## NFR Compliance` at the bottom.
- Backward compatibility with the old format is sensible.
- The migration script (opt-in, not automatic) is the right call.

### What's Weak

**1. `@nfr(NFR-XXXX)` tagging is unnecessary ceremony.**

The tag exists so tools can trace back from ACs to NFRs. But ask: how often does an NFR change after ACs are written? In practice, almost never. NFRs are stable constraints ("response time < 200ms"). They don't churn. The tracing problem the tag solves is rare.

A simpler alternative: write the NFR constraint as a normal AC in the `### NFR Constraints` group with a plain-text note like `(from NFR-0001)`. No special syntax, no parser changes, no tag scanning. `nfr-derive.sh --check` can just grep for `NFR-XXXX` references — it doesn't need a custom tag format.

**2. `nfr-derive.sh` auto-derivation is the weakest part of the plan.**

The plan says: "Agent contextualizes generated ACs for the specific feature (tool provides raw material, agent makes it feature-specific)." This is a two-step dance where the tool generates generic ACs and the agent rewrites them. But:
- NFRs are constraints, not feature behaviors. "Response time < 200ms" doesn't auto-derive into a testable feature AC — it requires knowing WHICH endpoint, WHICH scenario, WHAT data volume. The tool can't know this.
- What `nfr-derive.sh` can realistically do is list applicable NFRs by scope. That's a lookup, not a derivation. Call it `nfr-applicable.sh F-XXXX` — it prints which NFRs apply, the agent writes the ACs. Simpler, honest about what it does.

**3. NFR_PROPAGATION.md is another file that will drift.**

The plan replaces session-local `.qa-tracker.json` (which drifts) with git-tracked `NFR_PROPAGATION.md` (which will also drift, just more slowly). The fundamental problem: propagation tracking is bookkeeping that nobody reads proactively. The dashboard integration helps, but only if someone runs it.

Better alternative: make staleness detection a just-in-time check, not a durable file. When `ag implement F-XXXX` runs, check if any NFRs referenced in the acceptance file have been modified since the AC file was last updated. Use `git log` timestamps, not a tracking file. Zero maintenance, zero drift risk, same signal. The `nfr.sh` tool already has a propagation mechanism via `qa-tracker.sh` — that's the existing pattern, not a new file.

**4. The `<!-- nfr-derived: NFR-XXXX@date -->` staleness mechanism is fragile.**

Date-based comparison assumes `nfr-derive.sh` always writes the correct date, the AC file isn't reformatted by other tools, and the HTML comment survives all edits. This is a lot of assumptions for a staleness signal. `git log -1 --format=%ai -- .agentic/spec/NFR.md` vs `git log -1 --format=%ai -- .agentic/spec/acceptance/F-XXXX.md` is more robust and requires zero embedded metadata.

### Recommendation for Phase 1
Strip it down:
- Keep the template change (NFR Constraints group inside AC section) — this is the high-value part.
- Replace `nfr-derive.sh` with `nfr-applicable.sh` — a simple scope-matcher that lists which NFRs apply. The agent writes the actual ACs.
- Drop NFR_PROPAGATION.md. Use git-log-based staleness detection at `ag implement` time.
- Drop `@nfr(NFR-XXXX)` custom syntax. Use `(NFR-XXXX)` plain text — grep can find it, no parser needed.
- Drop `<!-- nfr-derived: ... -->` comment. Use git timestamps.

This cuts Phase 1 from "medium-high complexity, 10+ files" to "low-medium complexity, 5-6 files" and delivers the same user value.

---

## Phase 2: AC Clarity Gate — Good, Mostly Right

### What's Good
- Making `spec-analyze.sh` return non-zero for CRITICAL findings is overdue.
- Tightening the vague-word list (removing context-dependent words) shows good judgment — false positives erode trust.
- The `--force` bypass with journal logging is the right pattern.

### What's Weak

**The testability check is vaguely specified.**

"Each AC must have a concrete expected outcome" — how does a bash script detect this deterministically? The plan doesn't describe the heuristic. A regex for "system handles X" vs "system returns Y" will have high false-positive rates. The vague-word detection works because it's pattern matching against a known list. Testability is a semantic property that's much harder to check without LLM assistance.

### Recommendation
- Ship Phase 2 with just the tightened vague-word list + non-zero exit + gate. That's high value.
- Make testability a follow-up (or advisory-only from day one). Don't block implementation on a heuristic that's likely to produce false positives.

---

## Phase 3: AC Completeness Enforcement — Right Direction, Small Scope

### What's Good
- Fixing AC parsing to handle all formats is genuine bug-fixing — the current `grep -cE '^- AC-[0-9]+:'` in spec-audit.sh misses the `**AC-XXX**` format that the template actually uses.
- P1 at 100%, NFR ACs at 100%, P2/P3 at 80% — sensible thresholds.
- `ag done` as enforcement point (not pre-commit) — exactly right. By pre-commit, the work is done.

### What's Weak

**The parsing fix is actually the most impactful part of this whole epic.**

Looking at the existing code, `cmd_done()` in ag.sh (lines 1527-1558) already has AC completion checking, but the regex is:
```
grep -qE '^[[:space:]]*- \[[ x]\][[:space:]]*\*?\*?AC-'
```

Meanwhile `count_ac()` in spec-audit.sh uses:
```
grep -cE '^- AC-[0-9]+:'
```

These don't agree with each other, and neither handles all the formats in the wild. Fixing this one thing — consistent AC parsing across all tools — would deliver immediate value to every user.

### Recommendation
- Consider moving Phase 3 BEFORE Phase 1. The parsing fix + threshold enforcement is low-risk, high-impact, and has no dependencies on NFR format changes. A team could benefit from this immediately.

---

## Phase 4: Test Quality Verification — Partially Viable

### What's Good
- Stub assertion detection (`assert True`, `assert 1 == 1`) — this works. It's a simple regex, low false-positive rate, and catches a real problem.
- The "imports module but never calls its functions" check — clever and deterministic.

### What's Weak

**Assertion-strength heuristics are theater that gives false confidence.**

The plan proposes "assertion-to-lines ratio (test with 50 lines of setup and 1 assertion is suspicious)." This is a bad signal:
- Integration tests legitimately have long setup and few assertions ("does the whole pipeline produce the right output?" is one assertion after 50 lines of setup).
- Property-based tests have zero visible assertions (the framework generates them).
- E2E tests may have one assertion that checks a complex output object.

A low ratio doesn't mean bad tests. A high ratio doesn't mean good tests (10 `assertEqual(x, x)` assertions are worthless). The ratio is measuring the wrong thing.

**Per-AC coverage reporting assumes test files reference AC IDs, which they usually don't.**

The plan says "for each AC, show which test file(s) reference it." This requires tests to contain `AC-001` markers. In practice, test files reference feature IDs (`F-0148`) not individual ACs. The existing `coverage.py` already handles AC-to-test mapping via feature-level references. Per-AC granularity requires either (a) test naming conventions that nobody follows, or (b) LLM-based semantic matching (expensive, out of scope).

### Recommendation
- Keep: stub assertion detection, unused-import detection. These are simple, low-false-positive checks.
- Drop: assertion-to-lines ratio. It doesn't reliably indicate test quality.
- Reframe per-AC coverage: report at feature level (does any test reference F-XXXX?), not AC level. That's what the tools can actually verify.

---

## Phasing: Reorder for Faster Value

Current order: Phase 1 (NFR) -> Phase 2 (Clarity) -> Phase 3 (Completeness) -> Phase 4 (Tests)

The plan claims Phase 1 is the prerequisite because it changes the AC format. But:
- Phase 2 (clarity gate) works on the CURRENT format. It just checks vague words and blocks on CRITICAL. No dependency on NFR format.
- Phase 3 (completeness enforcement) is a parsing fix + threshold change. It works on any format.
- Phase 4 (test quality) is independent of AC format.

Only the NFR-specific parts of Phases 2-4 depend on Phase 1. And those parts are small.

**Recommended order:**
1. **Phase 3 first** (AC parsing fix + completeness enforcement) — immediate value, lowest risk, fixes an existing bug
2. **Phase 2 second** (clarity gate) — builds trust in the quality system
3. **Phase 1 third** (NFR integration, stripped down) — the template change is the foundation, but most user projects don't have NFRs yet, so it's less urgent
4. **Phase 4 last** (test quality, scoped down) — the least certain payoff

---

## What's Missing

### 1. AC format standardization across existing tools
The biggest immediate problem isn't any of the four phases — it's that `ag.sh`, `spec-audit.sh`, `spec-analyze.sh`, and `check-spec-health.sh` all parse ACs differently. A shared AC parsing function (even just a common grep pattern) would be higher leverage than any single phase.

### 2. Profile-aware enforcement
The plan doesn't address Discovery vs Formal profiles. Currently, `acceptance_criteria: blocking` vs `recommended` controls whether AC checks block. The new gates should respect this. Phase 2 (clarity gate) blocking in Discovery mode would be friction that drives users away.

### 3. The "spec-writing guidance" angle
The plan focuses on detection and enforcement but not on helping agents write BETTER ACs in the first place. The `spec_writing.md` workflow change (Phase 1) is the only guidance improvement. A simple addition: when `spec-analyze.sh` finds vague ACs, suggest a specific rewrite pattern (not just "add a metric"). This is cheap and would improve AC quality at the source.

### 4. LLM tests for the new gates
This is a framework development repo. Any new gate that changes agent behavior (Phase 2's blocking on vague ACs, Phase 3's stricter completion enforcement) needs LLM tests proving agents encounter and respond to the gates. The plan's verification section describes manual testing only.

---

## Feasibility Assessment

| Phase | Fits Existing Architecture? | Hidden Challenges |
|-------|----------------------------|-------------------|
| 1 (NFR, stripped) | Yes — template change + new tool + gate additions | NFR scope-matching needs clear rules ("Applies to: all" means every feature?) |
| 2 (Clarity) | Yes — extends existing spec-analyze.sh | False-positive tuning will take iteration |
| 3 (Completeness) | Yes — fixes existing code in ag.sh | Need to handle heading-format ACs (legacy) without breaking old features |
| 4 (Tests, scoped) | Yes — extends existing spec-audit.sh | Regex patterns for stub assertions need language-awareness (Python vs JS vs Go) |

No major architectural problems. The framework's existing tool + gate + hook pattern accommodates all four phases naturally.

---

## Summary: What to Change

1. **Reorder**: Phase 3 -> Phase 2 -> Phase 1 -> Phase 4
2. **Simplify Phase 1**: Drop `@nfr()` tags, NFR_PROPAGATION.md, `nfr-derived` comments. Use git timestamps + plain text references. Rename `nfr-derive.sh` to `nfr-applicable.sh` (honest about what it does).
3. **Scope Phase 2**: Ship vague-word + gate first, defer testability heuristic.
4. **Scope Phase 4**: Keep stub/unused-import detection, drop assertion ratio, reframe coverage to feature-level.
5. **Add**: Shared AC parsing utility. Profile-aware enforcement. LLM test plan.
6. **Add to Phase 3**: Extract a common AC parsing function that all tools share.
