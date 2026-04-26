# Plan: skills.sh Marketplace Integration for Stack-Specific Quality

**Owning feature:** F-008 (Code Quality Standards) — per "no feature inflation" rule. F-008 already ships 7 built-in stack-specific quality knowledge files (web, Python, Node, React Native, audio DSP, 2D web games, Unity). This enhancement adds an external marketplace ([skills.sh](https://skills.sh)) as a second source, letting us cover stacks we haven't hand-authored and pull in community best-practice skills.

**Status:** APPROVED (post dialectical review — see Revision Log at end)

---

## Context

Today F-008 injects stack-specific quality knowledge into Claude skills via `generate-skills.sh` from a fixed set of 7 in-repo stack YAML+markdown pairs. Stacks outside that list get nothing. skills.sh is a Vercel-maintained index of reusable Agent Skills (SKILL.md format) published from GitHub repos (`owner/repo`), with ~91k installs listed.

Two gaps to close:
1. **Init-time enrichment** — on `ag init`, after stack detection (`discover.py`), we should offer quality-relevant skills matched to the detected stack.
2. **Architecture-change reaction** — when a developer changes the stack mid-project (new dependency in `package.json`, new framework in STACK.md), installed skills go stale; no mechanism today nudges or re-syncs.

User answered three design Qs: **Init + auto-detect on STACK.md change**, **generate for all agents**, **curated mapping + confirm prompt**.

---

## Design Overview

Four moving parts, all built on existing infrastructure:

1. **Curated stack→skill mapping** (new allowlist file) — supply-chain safety; only mapped skills are installable
2. **`ag skills` CLI** (new command module) — suggest / install / sync / list / remove
3. **Init integration** — `cmd_init` calls suggest+confirm+install after `discover.py` completes
4. **STACK.md / manifest change hook** — new PostToolUse hook prints an unobtrusive nudge when stack signals change

Marketplace skills land in the existing extension point (`.agentic/local/extensions/skills/`), which `generate-skills.sh` already propagates to `.claude/skills/` (see generate-skills.sh:298-337). We extend `generate-cursor-skills.sh` to read the extension dir too — then Cursor/Copilot/Codex get them automatically. This preserves **PRINCIPLES D7 agent-agnostic**.

---

## Components

### 1. Curated stack→skill mapping
**New file:** `.agentic/lib/data/skills-marketplace.yaml`

Schema:
```yaml
version: 1
stacks:
  react:
    signals:        # any of these triggers match
      - package.json:dependencies.react
      - package.json:dependencies.next
      - STACK.md:React
    skills:
      - id: vercel-labs/frontend-design
        reason: React component + design conventions
        sha: <pinned-commit>   # optional pin for reproducibility
  python:
    signals: [pyproject.toml, requirements.txt]
    skills: [...]
  typescript:
    signals: [tsconfig.json, package.json:devDependencies.typescript]
    skills: [...]
  # initial seeds: react, next, typescript, python, node, go, rust, azure
```

This is the **allowlist**. Anything not listed here cannot be installed via `ag skills`. Edits to this file are framework-maintainer decisions; user projects do not extend it (use `.agentic/local/extensions/skills/` for custom skills instead).

### 2. `ag skills` CLI
**New:** `.agentic/lib/tools/commands/skills.sh` with `cmd_skills()` dispatcher
**New:** `.agentic/lib/tools/skills_marketplace.py` (fetch, match, install logic in Python — matches `discover.py` pattern)

Subcommands:
- `ag skills suggest` — read STACK.md + manifests, match against mapping, print proposed skills with source URL + reason. No writes.
- `ag skills install [--all | --select <id>...]` — interactive confirm prompt listing each skill + source URL + reason; fetch SKILL.md + references from GitHub raw (NOT running `npx skillsadd` — avoids executing arbitrary npm), place in `.agentic/local/extensions/skills/<skill-name>/`, then invoke `generate-skills.sh` + `generate-cursor-skills.sh` to fan out.
- `ag skills sync` — diff installed vs. recommended-for-current-stack; prompt add/remove.
- `ag skills list` — show installed marketplace skills + source + pinned sha.
- `ag skills remove <id>` — delete from extension dir and regenerate.

**Safety:**
- Fetch only from GitHub raw (HTTPS); reject other hosts.
- Compute sha256 of fetched SKILL.md, record in `.agentic/local/extensions/skills/<name>/.source.json`.
- If the skill ships `scripts/`, do **not** copy them silently. List them to the user and require `--accept-scripts`. This is the supply-chain review point.
- Offline/unreachable: fail gracefully, keep existing installs intact.

### 3. Init integration
**Modify:** `.agentic/lib/tools/commands/operations.sh` `cmd_init` (lines 797-842)

After `discover.sh` completes and STACK.md is populated, call `ag skills suggest`. If matches exist, print:
```
📦 Stack-matched quality skills available from skills.sh:
  - vercel-labs/frontend-design    — React component + design conventions
  - anthropics/skills#python       — PEP8, type hints, pytest
Install these? [Y/n/select]
```
`Y` → `ag skills install --all`. `select` → interactive multi-select. `n` → skip, stored preference in `.agentic/local/skills-preferences.json` so init doesn't re-ask on repeated init.

### 4. Architecture-change hook
**New:** `.agentic/lib/hooks/shared/on-stack-change.sh`
**Modify:** `.claude/hooks.json` — add a `PostToolUse` entry for matcher `Write|Edit|MultiEdit`

Hook logic:
1. Read Claude hook JSON input from stdin; extract `tool_input.file_path`.
2. If path matches STACK.md, package.json, requirements.txt, pyproject.toml, Cargo.toml, go.mod, Gemfile → proceed; else exit 0 silently.
3. Run `ag skills sync --dry-run` (fast, read-only).
4. If diff is non-empty, print one line to additionalContext: `🧩 Stack signals changed — N skill(s) to add, M to remove. Run: ag skills sync`.

Does **not** auto-install. User keeps control; hook is a nudge only. Respects existing framework pattern (PostToolUse hooks nudge, don't mutate).

---

## Files to Create / Modify

**Create:**
- `.agentic/lib/data/skills-marketplace.yaml` — curated allowlist
- `.agentic/lib/tools/commands/skills.sh` — CLI module
- `.agentic/lib/tools/skills_marketplace.py` — fetch/match/install engine
- `.agentic/lib/hooks/shared/on-stack-change.sh` — change-detection hook
- `.agentic/spec/contracts/F-008-skills-marketplace.yaml` — AC extension for F-008 (contract-driven workflow)
- `tests/unit/test_skills_marketplace.sh` — fetch/match unit tests (mock GitHub raw)
- `tests/llm/test_skills_trigger.sh` — **mandatory per framework rule**; validates agent runs `ag skills sync` when user says "stack changed"
- `.agentic/work/F-008-skills-marketplace/plan.md` — durable plan (copy this file)

**Modify:**
- `.agentic/lib/tools/ag.sh` — register `skills` in case statement (~line 236-432 switch)
- `.agentic/lib/tools/commands/operations.sh` — extend `cmd_init()` (lines 797-842)
- `.agentic/lib/tools/generate-cursor-skills.sh` — iterate `.agentic/local/extensions/skills/` in addition to `CLAUDE_SKILLS_DIR` (line 16) so marketplace skills reach Cursor
- Equivalent generators for Codex/Copilot if they exist (check `generate-*-skills.sh` siblings); add extension-dir pass if missing
- `.claude/hooks.json` — add PostToolUse entry for stack-change hook
- `.agentic/spec/FEATURES.md` — update F-008 description: "+ skills.sh marketplace integration for stacks beyond the built-in 7"
- **Instruction files (framework-dev dogfood requirement):**
  - `CLAUDE.md` (root) + `.agentic/lib/agents/claude/CLAUDE.md` — add `ag skills` to command list
  - `.cursorrules`, `.agentic/lib/agents/cursor/*`
  - `.agentic/lib/agents/copilot/*`, `.agentic/lib/agents/codex/*`
  - `.agentic/lib/init/memory-seed.md` — add trigger word table entry: `"install skills / stack skills / marketplace"` → `ag skills suggest`
  - `DEVELOPER_GUIDE.md`, `HOW_IT_WORKS.md` — document the marketplace flow

---

## Key Functions / Utilities Reused

- `discover.py` (`.agentic/lib/tools/discover.py`) — already extracts language/framework/package-manager. `skills_marketplace.py` calls `discover.py --json` instead of reimplementing stack detection.
- `generate-skills.sh:298-337` — existing extension-skill pipeline; marketplace installs drop into its input dir.
- `generate-cursor-skills.sh:27-54` — loop pattern; extend to a second source dir.
- `.agentic/local/extensions/skills/` — extension point created by `scaffold.sh:222-253`; already in-scheme, no new directory concept needed.
- Hook JSON-stdin pattern used by `on-code-edit.sh`, `on-bash-merge-detect.sh` — copy that shape for `on-stack-change.sh`.
- `blocker.sh`, `journal.sh`, `status.sh` — for logging install events.

---

## Verification

1. **Unit:** `bash tests/unit/test_skills_marketplace.sh` — mocks GitHub raw, asserts allowlist enforcement, sha recording, script-quarantine.
2. **Framework validation:** `bash tests/validate_framework.sh` passes.
3. **End-to-end (scratch project):**
   - Scaffold scratch React repo (`package.json` with `react` dep) → `ag init` → prompt offers `vercel-labs/frontend-design` → accept → verify SKILL.md appears in `.claude/skills/` AND `.cursor/skills/` AND `.agentic/local/extensions/skills/`.
   - Edit `package.json` to add `vue` → PostToolUse hook fires → additionalContext shows sync nudge.
   - Run `ag skills sync` → interactive prompt offers vue skill + keep/remove unused ones.
   - Disable network (`HTTPS_PROXY=http://127.0.0.1:1`) → `ag skills install` fails gracefully, no partial state.
   - A marketplace skill with `scripts/` → install is blocked without `--accept-scripts`; with the flag, scripts listed for review before copy.
4. **LLM test:** assert that "my stack just changed, I added vue" triggers `ag skills sync` (not direct edits).
5. **Dogfood:** run it on this repo — we already have STACK.md and a detectable tech stack — and confirm mapping suggests sensible skills (node, python, shell).

---

## Open Questions / Risks (for dialectical review to surface)

- **Curated mapping freshness:** who owns updates? Propose quarterly review by framework maintainers; log in JOURNAL.md.
- **Skill drift:** upstream GitHub repo for a mapped skill disappears or changes. Store sha, warn on mismatch at `ag skills sync` time.
- **Overlap with built-in F-008 quality files:** if both a built-in Python stack file AND a marketplace python skill install, do they conflict? Mitigation: marketplace skills go in a separate Claude skill name space (`marketplace-<id>`) so both can coexist; user picks which guides behavior.
- **Scripts field on SKILL.md:** marketplace skills can declare `allowed-tools: [Bash]` and ship scripts. Quarantine + `--accept-scripts` gate is the mitigation, but deserves careful review.

---

## Revision Log (post dialectical review, 2026-04-13)

Critic and Advocate agreed the core design (F-008 enhancement, curated allowlist + confirm, GitHub raw fetch, extension-dir landing zone, nudge-not-mutate hook) is sound. Ten refinements accepted and folded into the plan:

**Security hardening:**
- **[R1] sha pin is MANDATORY**, not optional. `skills-marketplace.yaml` schema requires `sha` on every skill entry. `ag skills install` refuses to fetch without a pin. Add `ag skills update-pins` for maintainers. (Critic #3)
- **[R6] Rate-limit + proxy support.** `skills_marketplace.py` honors `GITHUB_TOKEN` (raises rate limit 10x), `HTTPS_PROXY`, `NO_PROXY`. Cache fetched content in `.agentic/local/cache/skills/` with TTL + sha verification. (Critic #6)

**Correctness / UX:**
- **[R2] Hook fast-path.** `on-stack-change.sh` does basename-match in pure bash FIRST (exits 0 in ~0ms on non-matches). Python `ag skills sync --dry-run` runs only when basename matches `STACK.md|package.json|pyproject.toml|Cargo.toml|go.mod|Gemfile|requirements.txt`. (Critic #2)
- **[R4] Precedence rule for F-008 built-in vs marketplace conflicts.** Built-in F-008 quality guidance wins. `generate-skills.sh` emits a preamble into marketplace skills: `> This is a community skill. On any conflict with framework built-in quality guidance (F-008 stack files), built-in wins.` Plus: `ag skills install` skips marketplace skills for stacks already covered by a built-in F-008 file unless `--override-builtin`. (Critic #4, Advocate Concession 2)
- **[R5] Uninstall-on-stack-shrink.** `ag skills sync` detects orphaned skills (installed marketplace skill with no matching current-stack signal) and proposes removal. Added to AC. (Critic #5)
- **[R7] Non-interactive init.** `ag init` auto-detects no-TTY and skips the prompt with an info log. Adds `--no-skills` flag for explicit opt-out in scripted flows. (Critic #7)
- **[R9] Broader trigger phrases + LLM test variants.** memory-seed adds: "install skills / stack skills / marketplace / best practices for <stack> / quality skills / stack recommendations / what skills". LLM test gets 3 variants: direct ("my stack changed"), indirect ("best practices for React"), discovery ("what skills available"). (Critic #9)

**Agent-agnostic (real D7 gap):**
- **[R8/CritMerge-1] Scope clarified.** Phase 1 ships full parity for Claude + Cursor. Copilot + Codex don't have per-skill fan-out mechanisms today — instead, marketplace-skill content gets appended as a section into their single instruction files (`copilot-instructions.md`, `codex-instructions.md`) via a new `generate-copilot-skills-inject.sh` that produces a bounded `<!-- MARKETPLACE-SKILLS-START -->...<!-- END -->` block. This is the honest D7 fulfillment given their architectures. Explicit deliverable, not hand-wave.

**Scope + shippability:**
- **[R10] Three-PR phasing.** This feature will be shipped as three sequential PRs under F-008, not one: PR-A: allowlist + `skills_marketplace.py` + `ag skills` CLI (usable manually). PR-B: init integration + non-interactive handling. PR-C: stack-change hook + instruction-file sync + LLM tests. Each PR has its own verification pass. (Critic #10, Advocate Concession 3)

**Sustainability:**
- **[R11/Critic #8] Community contribution path.** `ag skills request <github-repo-url>` creates a templated GitHub issue (via `gh issue create`) with the skill URL, detected stack signal, and rationale — structured feedback to framework maintainers instead of ad-hoc Slack/DM requests. Acknowledges scale limit; formalizes the loop.

**Unchanged (Advocate defended successfully):**
- F-008 ownership (not new F-XXXX)
- Curated allowlist + confirm (correct tradeoff vs auto or list-only)
- GitHub raw over `npx skillsadd` (arbitrary JS execution is not acceptable)
- Extension dir as landing zone (input/output separation)
- PostToolUse nudge over auto-sync (matches framework pattern)
