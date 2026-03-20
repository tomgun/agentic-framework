# Framework Development Quick Start

**Scope**: Agents working ON the Agentic Framework itself (not projects using it).

**Full reference**: `FRAMEWORK_DEVELOPMENT.md` | **Principles rationale**: `.agentic/PRINCIPLES.md`

---

## 🚨 CORE PRINCIPLES

Every decision must align with these. If conflict, re-read `PRINCIPLES.md` (13 principles: F1-F3 → D1-D7 → R1-R3).

| Principle | What It Means for Framework Dev |
|-----------|--------------------------------|
| **Developer UX** (F1) | User remembers nothing; specs/WIP/STATUS carry state; agent guides proactively |
| **Sustainable Quality** (F2) | Spec ↔ Acceptance Criteria ↔ Tests ↔ Code — ALL must match current committed version |
| **Token & Context Optimization** (F3) | Durable artifacts, efficient scripts, context isolation |
| **Gates > Guidelines** (D2) | Enforcement (hooks, scripts) over advice (docs) |
| **Small Batch + Acceptance-Driven** (D4) | One feature at a time, max 5-10 files per commit. Write acceptance criteria (even rough bullet points) BEFORE implementation, not after |
| **Living Documentation** (D5) | Update docs WITH code in same commit, never "later". Test that workflows actually work; don't assume |
| **Single Source of Truth** | Information lives in ONE place; others reference it |
| **Internal Consistency** | Templates + examples + docs + agent guidelines must align |
| **Dogfooding** | Framework follows its own spec-driven methodology |
| **Backward Compatibility** | Existing projects must upgrade cleanly |

---

## 🏗️ ARCHITECTURE: Three Layers (v2)

| Layer | What | v2 Files | Rule |
|-------|------|----------|------|
| **Constitution** | Structural enforcement + behavioral rules | `state_machine_af.yaml` (CLI enforcement) + CLAUDE.md, .cursorrules, etc. (<100 lines) | CLI enforces transitions; instruction files cover what can't be structurally enforced. |
| **Playbooks** | Role-specific guidance | 7 role prompts in `.agentic/prompts/` + `conventions.md` | Loaded JIT on state transitions. Role prompt emitted by CLI when transition succeeds. |
| **State** | Per-feature work items | `.agentic/work/F-XXXX/item.yaml` + co-located artifacts (plan.md, spec.md, review.md, verification.json) | Git-tracked = cross-machine. Gitignored = session-local. |

**v2 workflow commands**: `ag start F-XXXX "Title"` | `ag transition F-XXXX <state>` | `ag check F-XXXX` | `ag verify F-XXXX` | `ag ship F-XXXX` | `ag status` | `ag info F-XXXX` | `ag next`

**Work items** live in `.agentic/work/F-XXXX/` — all artifacts co-located. Preconditions (e.g., "plan.md must exist") checked by CLI before transitions.

**Design basis**: [`docs/INSTRUCTION_ARCHITECTURE.md`](docs/INSTRUCTION_ARCHITECTURE.md)

---

## 📦 TWO PROFILES: Discovery vs Formal

Framework features apply to different profiles:

| Profile | What Users Get | Key Files |
|---------|---------------|-----------|
| **Discovery** | Token efficiency, developer UX, workflows, quality gates | STATUS.md, CONTEXT_PACK.md, JOURNAL.md, .agentic/session/WIP.md |
| **Formal** | Discovery + formal specs, feature tracking, acceptance criteria | + .agentic/spec/FEATURES.md, .agentic/spec/acceptance/ |

**When adding framework features, know which profile it affects:**
- Discovery features → affect ALL users
- Formal features → only users who enable formal specs
- Both → document clearly in .agentic/spec/FEATURES.md

**Discovery is the foundation** - Token Economics and Developer UX must work without any specs.

---

## 🔴 BEFORE ANY FRAMEWORK CHANGE

Ask yourself:

1. **Does it align with principles above?** → If not, reconsider
2. **Will it affect templates?** → Test in scratch project first
3. **Will it affect examples?** → Consider updating `examples/` (not blocking, but recommended)
4. **Is it a new feature?** → Must be specced (see below)
5. **Does it break existing projects?** → Provide upgrade path in `upgrade.sh`
6. **Did you test it actually works?** → Run in scratch project, don't assume

---

## ✅ ADDING A FRAMEWORK FEATURE (Mandatory Steps)

| # | File | Action | Why |
|---|------|--------|-----|
| 1 | `.agentic/spec/FEATURES.md` | Add F-#### entry | Dogfooding: we spec our own features |
| 2 | `.agentic/spec/acceptance/F-####.md` | Create acceptance criteria FIRST | Acceptance-Driven: criteria before code |
| 3 | Code | Implement the feature | Now you know what "done" means |
| 4 | `tests/validate_framework.sh` | Add validation tests | Gates > Guidelines: enforce, don't advise |
| 5 | Scratch project | Test the feature works | Documentation = Reality |
| 6 | `bash .agentic/tools/drift.sh --docs` | Check for stale documentation | Living docs: catch drift early |
| 7 | `CHANGELOG.md` | Document the change | Living docs |
| 8 | `CONTRIBUTIONS.md` | Add version section | Attribution |
| 9 | `upgrade.sh` FEATURE_REGISTRY | If user-visible during upgrade | Developer UX |
| 10 | `.agentic/agents/claude/CLAUDE.md` | Sync if guidelines/principles changed | Bootstrap must be self-contained (see ADR-001). Design: `docs/INSTRUCTION_ARCHITECTURE.md` — instruction files serve the orchestrator only; subagents get context via `context-for-role.sh`. |
| 11 | `bash .agentic/tools/manifest.sh F-####` | Generate change manifest | Audit trail of what changed |

**Feature is "accepted" when**: Tests pass in `validate_framework.sh` AND developer has reviewed tests and results.

> **Spec Protection**: Once a feature ships, its acceptance criteria become a contract.
> Pre-commit Checks 14-16 block changes to shipped specs without a migration
> (`bash .agentic/lib/tools/migration.sh create`). See `.agentic/lib/checklists/spec_writing.md`.

**Note**: Further development may break features. Re-run `validate_framework.sh` regularly.

---

## 🔀 GIT WORKFLOW (PR-Based)

Framework development uses PR workflow (dogfooding):

```bash
# 1. Create feature branch
git checkout -b feature/F-0098-description

# 2. Work, commit to branch
git commit -m "feat(scope): description"

# 3. Push and create PR
git push -u origin feature/F-0098-description
gh pr create --title "feat: Description (F-0098)"

# 4. Merge after review
```

**Never commit directly to main** - always use feature branches + PRs.

---

## 🔄 RELEASE CHECKLIST (Abbreviated)

```
[ ] .agentic/spec/FEATURES.md has new features (F-####)
[ ] .agentic/spec/acceptance/F-####.md exists for each new feature
[ ] tests/validate_framework.sh passes (ALL tests)
[ ] LLM behavioral tests current (bash .agentic/tools/llm-test-status.sh)
[ ] Tested in scratch project (install.sh, init, upgrade)
[ ] CHANGELOG.md updated
[ ] CONTRIBUTIONS.md updated
[ ] VERSION file updated
[ ] Version references updated (README, DEVELOPER_GUIDE, etc.)
[ ] Git tag: git tag -a vX.Y.Z -m "Release vX.Y.Z"
[ ] Push: git push origin main vX.Y.Z
```

Full checklist: `FRAMEWORK_DEVELOPMENT.md` → Section 11

---

## 📁 KEY FILES

## 🔍 QUALITY ASSURANCE SUITE (v0.46.0+)

The framework includes a formal QA pipeline — "who tests the tests?"

| Command | What It Does |
|---------|-------------|
| `ag audit` | Verify spec→AC→test chain (structural, coverage, heuristics, LLM review) |
| `ag audit --full` | Full audit report to `docs/retrospectives/` |
| `ag audit --propagate NFR-XXXX` | Trace NFR changes to affected features downstream |
| `ag audit --metrics` | Spec evolution data: discovery markers, churn analysis |
| `ag audit --status` | Show QA tracker summary |
| `ag nfr list` | List all project NFRs with status |
| `ag nfr discover` | Suggest NFRs from catalog based on project stack |
| `ag nfr coverage` | Show which features reference each NFR |

**Key tools**: `spec-audit.sh` (verification), `qa-tracker.sh` (state machine with escalation), `test-review-prompt.md` (LLM test intent review)

**Escalation**: propagation items auto-escalate from info → warn (3d) → escalate (7d) → block retro (14d). Configurable via `qa_propagation_warn_days` / `qa_propagation_escalate_days` settings.

---

| Purpose | File |
|---------|------|
| Framework specs | `.agentic/spec/FEATURES.md` |
| Acceptance criteria | `.agentic/spec/acceptance/F-####.md` |
| Spec migrations | `.agentic/spec/migrations/` (use `migration.sh create "title"`) |
| Validation tests | `tests/validate_framework.sh` |
| LLM test plan | `tests/LLM_TEST_PLAN.md` |
| LLM test results | `tests/LLM_TEST_RESULTS.md` |
| How to run LLM tests | `tests/RUN_LLM_TESTS.md` |
| QA audit tool | `.agentic/lib/tools/spec-audit.sh` |
| QA tracker | `.agentic/lib/tools/qa-tracker.sh` |
| NFR catalog | `.agentic/lib/init/nfr-catalog.md` |
| Upgrade notifications | `.agentic/lib/tools/upgrade.sh` → FEATURE_REGISTRY |
| Templates | `.agentic/lib/init/*.template.md` |
| Agent guidelines | `.agentic/lib/agents/shared/` |
| Full dev guide | `FRAMEWORK_DEVELOPMENT.md` |
| Principles | `.agentic/lib/PRINCIPLES.md` |
| Change manifests | `.agentic/journal/manifests/` (use `manifest.sh F-####`) |
| Doc drift check | `drift.sh --docs` or `drift.sh --docs --manifest F-####` |

---

## ⚠️ COMMON MISTAKES

| Mistake | Consequence | Prevention |
|---------|-------------|------------|
| Code without spec | Untraceable, undocumented | Always F-#### first |
| Spec without acceptance criteria | No definition of "done" | Always create F-####.md BEFORE coding |
| Acceptance without test | Gate doesn't enforce | Always update validate_framework.sh |
| Change templates without testing | Breaks all future projects | Test in scratch project |
| Assume it works | Broken workflows shipped | Actually run it, verify output |
| Docs "later" | Docs become stale/wrong | Same commit as code |
| Scattered version refs | Users install wrong version | Update ALL version references on release |

---

## 🧪 TESTING FRAMEWORK CHANGES

**Before committing**:

```bash
# 1. Create scratch project
mkdir /tmp/test-framework && cd /tmp/test-framework && git init

# 2. Install framework
bash /path/to/agentic-framework/install.sh .

# 3. Test init works
# (run through init_playbook.md with agent)

# 4. Test tools work
python3 .agentic/tools/doctor.py
bash .agentic/tools/wip.sh check

# 5. If changing upgrade.sh, test upgrade path
cd /tmp/old-project  # existing project on older version
bash /path/to/new-framework/.agentic/tools/upgrade.sh .
```

---

**Remember**: Framework changes affect ALL users.

**The chain**: Spec → Acceptance Criteria → Code → Tests → Docs — all in sync, all matching committed version.
