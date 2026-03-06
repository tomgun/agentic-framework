# Plan: Restructure `.agentic/` Directory Layout

## Context

The `.agentic/` directory currently commits 369 framework library files (~1.1MB) to every project repo, polluting git history. Three separate `.agentic*` directories and 18 root-level .md files create clutter. This restructure consolidates everything under a single `.agentic/` directory with clear separation between framework runtime (`lib/`), project tracking files (flat at `.agentic/` root), specs (`spec/`), journal (`journal/`), user extensions (`local/`), and session state (`session/`).

**Key decisions:**
- Framework repo and user projects use the **same directory structure**, different commit strategies
- Framework repo commits `lib/`; user projects gitignore it (extracted from package)
- GitHub release workflow builds a **lib-only tarball** as a release artifact
- Project tracking files (STATUS.md, TODO.md, etc.) move flat into `.agentic/` root
- Specs move into `.agentic/spec/`
- Journal is a sibling directory at `.agentic/journal/`

## Target Structure

```
project-root/
├── CLAUDE.md                         # Constitution (tool requirement)
├── .cursorrules                      # Constitution (tool requirement)
├── CODEX.md                          # Constitution (tool requirement)
├── README.md                         # Project readme
├── AGENTS.md                         # Multi-agent coordination
├── STACK.md                          # Project config + framework version
├── CONTEXT_PACK.md                   # Architecture snapshot
│
└── .agentic/
    ├── bootstrap.sh                  # COMMITTED EVERYWHERE (~30 lines)
    ├── ag                            # COMMITTED EVERYWHERE (~15 lines)
    ├── agentic-lib-v0.41.0.tar.gz    # COMMITTED IN USER PROJECTS (lib package)
    │
    │── STATUS.md                     # Project tracking (was root STATUS.md)
    │── TODO.md                       # Project tracking (was root TODO.md)
    │── HUMAN_NEEDED.md               # Project tracking (was root HUMAN_NEEDED.md)
    │── CONTRIBUTIONS.md              # Project tracking (was root CONTRIBUTIONS.md)
    │── OVERVIEW.md                   # Project overview (was root OVERVIEW.md)
    │
    ├── journal/                      # GIT-TRACKED - Development history (was .agentic-journal/)
    │   ├── JOURNAL.md
    │   ├── plans/
    │   ├── lessons/
    │   ├── manifests/
    │   └── reviews/
    │
    ├── spec/                         # GIT-TRACKED - Project specs (was root spec/)
    │   ├── FEATURES.md
    │   ├── ISSUES.md
    │   ├── NFR.md
    │   ├── REFERENCES.md
    │   ├── LESSONS.md
    │   ├── acceptance/               # F-0001.md, F-0002.md, ...
    │   ├── adr/
    │   └── migrations/
    │
    ├── local/                        # GIT-TRACKED - User extensions (survives upgrades)
    │   ├── extensions/
    │   ├── gates/
    │   └── rules/
    │
    ├── session/                      # GITIGNORED - Ephemeral (was .agentic-state/)
    │   ├── WIP.md
    │   ├── AGENTS_ACTIVE.md
    │   ├── plans/
    │   └── proposals/
    │
    ├── hooks/                        # COMMITTED EVERYWHERE - Thin wrappers
    │   ├── pre-commit                # Delegates to lib/hooks/pre-commit
    │   └── claude/                   # Claude Code hook wrappers
    │       ├── hooks.json
    │       ├── SessionStart.sh       # Inlines bootstrap, then delegates
    │       ├── PreCompact.sh
    │       ├── Stop.sh
    │       ├── PostToolUse.sh
    │       └── UserPromptSubmit.sh
    │
    └── lib/                          # Framework runtime
        │                             #   COMMITTED in framework repo (source of truth)
        │                             #   GITIGNORED in user projects (extracted from package)
        ├── tools/                    # ag.sh, status.sh, journal.sh, etc.
        ├── agents/                   # Agent guidelines, roles, skills sources
        ├── workflows/                # Playbooks (TDD, git, spec evolution)
        ├── quality/                  # Standards, design-for-testability
        ├── checklists/               # Session start, feature complete
        ├── init/                     # Scaffolding, setup
        ├── templates/                # RENAMED from spec/ — spec/feature/NFR templates
        ├── hooks/                    # Git hook IMPLEMENTATIONS
        ├── claude-hooks/             # Claude Code hook IMPLEMENTATIONS
        ├── prompts/                  # Tool-specific prompts
        ├── schemas/                  # JSON schemas
        ├── presets/                  # Profile presets
        ├── support/                  # CI, design systems, stack profiles
        ├── token_efficiency/         # Token optimization guides
        ├── quality_profiles/         # Profile-specific settings
        ├── settings.sh              # Shared bash library
        ├── settings.py              # Shared python library
        ├── paths.sh                 # NEW: Central path resolver
        ├── PRINCIPLES.md
        ├── DEVELOPER_GUIDE.md
        ├── VERSION
        └── ...
```

### Key naming decisions

- **Flat tracking files** at `.agentic/` root: STATUS.md, TODO.md, etc. — shallow paths, no wrapper directory needed
- **`journal/`** as sibling: historical data (plans, lessons, manifests) separate from active tracking
- **`lib/templates/`** instead of `lib/spec/`: avoids confusion with `.agentic/spec/` (project specs). Templates are templates, not specs.
- **`lib/`** with flattened internals: existing `settings.sh`/`settings.py` stay at `lib/` root (same path as today). All other framework dirs move INTO `lib/`.

## Release & Distribution Model

### Current flow (problematic)
```
GitHub tag → source tarball (full repo ~3MB) → remote-install.sh downloads
→ install.sh copies .agentic/ dir to target → 369 files committed to user repo
```

### New flow
```
GitHub tag → GitHub Actions builds agentic-lib-v{VERSION}.tar.gz (lib/ only, ~250KB)
→ release artifact attached alongside source tarball
→ remote-install.sh downloads lib tarball + thin wrappers
→ install.sh extracts lib/ + saves tarball to .agentic/ + scaffolds tracking files
→ User repo commits: tarball + thin wrappers + tracking files + spec/ (no lib/ in git)
```

### Release artifacts
1. **Source tarball** (auto-generated by GitHub) — full repo, for framework developers
2. **`agentic-lib-v{VERSION}.tar.gz`** (built by CI) — just lib/ contents, for installation

The lib tarball extracts flat into `.agentic/lib/`:
```
tar xzf agentic-lib-v0.41.0.tar.gz -C .agentic/lib/
```

### Build step (GitHub Actions)
```yaml
# .github/workflows/release.yml
- name: Build lib tarball
  run: |
    mkdir -p dist
    tar czf dist/agentic-lib-v${{ github.ref_name }}.tar.gz \
      -C .agentic/lib \
      tools agents workflows quality checklists init templates hooks claude-hooks \
      prompts schemas presets support token_efficiency quality_profiles \
      settings.sh settings.py paths.sh \
      PRINCIPLES.md DEVELOPER_GUIDE.md VERSION

- name: Upload to release
  uses: softprops/action-gh-release@v1
  with:
    files: dist/agentic-lib-v*.tar.gz
```

## Bootstrap Mechanism

`bootstrap.sh` (~25 lines) — always executed, never sourced:

```bash
#!/usr/bin/env bash
set -euo pipefail
AGENTIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$AGENTIC_DIR/lib"

# Already available? (committed source in framework repo, or previously extracted)
[[ -d "$LIB_DIR/tools" ]] && exit 0

# Extract from committed package
tarball="$(ls "$AGENTIC_DIR"/agentic-lib-v*.tar.gz 2>/dev/null | sort -V | tail -1)"
if [[ -n "$tarball" ]]; then
  tmp_dir="$AGENTIC_DIR/.lib-extracting-$$"
  mkdir -p "$tmp_dir"
  tar xzf "$tarball" -C "$tmp_dir"
  mv "$tmp_dir" "$LIB_DIR"  # Atomic on same filesystem
  echo "Framework extracted from $(basename "$tarball")" >&2
  exit 0
fi

# Fallback: download from GitHub releases
version=$(grep -oP 'Version:\s*\K[\d.]+' "$AGENTIC_DIR/../STACK.md" 2>/dev/null || true)
if [[ -n "$version" ]]; then
  echo "Downloading agentic-lib-v${version}.tar.gz..." >&2
  tmp_dir="$AGENTIC_DIR/.lib-extracting-$$"
  mkdir -p "$tmp_dir"
  url="https://github.com/OWNER/agentic-framework/releases/download/v${version}/agentic-lib-v${version}.tar.gz"
  if curl -fsSL "$url" | tar xz -C "$tmp_dir"; then
    mv "$tmp_dir" "$LIB_DIR"
    exit 0
  fi
  rm -rf "$tmp_dir"
fi

echo "ERROR: Framework lib not found. Run install or place agentic-lib-v*.tar.gz in .agentic/" >&2
exit 1
```

`ag` wrapper:
```bash
#!/usr/bin/env bash
AGENTIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$AGENTIC_DIR/bootstrap.sh" || { echo "Bootstrap failed" >&2; exit 1; }
exec bash "$AGENTIC_DIR/lib/tools/ag.sh" "$@"
```

Hook thin wrapper (must inline bootstrap since hooks fire before any `ag` command):
```bash
#!/usr/bin/env bash
# .agentic/hooks/claude/SessionStart.sh
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-.}"
bash "$PROJECT_ROOT/.agentic/bootstrap.sh" 2>/dev/null || exit 0
exec bash "$PROJECT_ROOT/.agentic/lib/claude-hooks/SessionStart.sh"
```

## Path Resolution: `paths.sh`

Central path resolver at `.agentic/lib/paths.sh` — the **first deliverable**, created before anything moves:

```bash
#!/usr/bin/env bash
# Source this from any tool script:
#   source "$(dirname "${BASH_SOURCE[0]}")/paths.sh"       (from lib/ root)
#   source "$(dirname "${BASH_SOURCE[0]}")/../paths.sh"     (from lib/tools/)

AGENTIC_LIB="${AGENTIC_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
AGENTIC_ROOT="$(cd "$AGENTIC_LIB/.." && pwd)"
PROJECT_ROOT="$(cd "$AGENTIC_ROOT/.." && pwd)"

# Project config (stays at project root)
STACK_FILE="$PROJECT_ROOT/STACK.md"
CONTEXT_PACK_FILE="$PROJECT_ROOT/CONTEXT_PACK.md"
AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"

# Tracking files (flat at .agentic/ root)
STATUS_FILE="$AGENTIC_ROOT/STATUS.md"
TODO_FILE="$AGENTIC_ROOT/TODO.md"
HUMAN_NEEDED_FILE="$AGENTIC_ROOT/HUMAN_NEEDED.md"
CONTRIBUTIONS_FILE="$AGENTIC_ROOT/CONTRIBUTIONS.md"
OVERVIEW_FILE="$AGENTIC_ROOT/OVERVIEW.md"

# Journal
JOURNAL_DIR="$AGENTIC_ROOT/journal"
JOURNAL_FILE="$JOURNAL_DIR/JOURNAL.md"
PLANS_DIR="$JOURNAL_DIR/plans"
LESSONS_DIR="$JOURNAL_DIR/lessons"

# Specs
SPEC_DIR="$AGENTIC_ROOT/spec"
FEATURES_FILE="$SPEC_DIR/FEATURES.md"
ISSUES_FILE="$SPEC_DIR/ISSUES.md"
NFR_FILE="$SPEC_DIR/NFR.md"
ACCEPTANCE_DIR="$SPEC_DIR/acceptance"

# Session (ephemeral)
SESSION_DIR="$AGENTIC_ROOT/session"
WIP_FILE="$SESSION_DIR/WIP.md"
AGENTS_ACTIVE_FILE="$SESSION_DIR/AGENTS_ACTIVE.md"

# Framework lib
TOOLS_DIR="$AGENTIC_LIB/tools"
AGENTS_LIB_DIR="$AGENTIC_LIB/agents"
WORKFLOWS_DIR="$AGENTIC_LIB/workflows"
CHECKLISTS_DIR="$AGENTIC_LIB/checklists"
TEMPLATES_DIR="$AGENTIC_LIB/templates"

# Backward compatibility — check both new and legacy locations
_compat() { [[ ! -f "$1" && -f "$2" ]] && echo "$2" || echo "$1"; }
STATUS_FILE="$(_compat "$AGENTIC_ROOT/STATUS.md" "$PROJECT_ROOT/STATUS.md")"
TODO_FILE="$(_compat "$AGENTIC_ROOT/TODO.md" "$PROJECT_ROOT/TODO.md")"
HUMAN_NEEDED_FILE="$(_compat "$AGENTIC_ROOT/HUMAN_NEEDED.md" "$PROJECT_ROOT/HUMAN_NEEDED.md")"
JOURNAL_FILE="$(_compat "$AGENTIC_ROOT/journal/JOURNAL.md" "$PROJECT_ROOT/.agentic-journal/JOURNAL.md")"
FEATURES_FILE="$(_compat "$AGENTIC_ROOT/spec/FEATURES.md" "$PROJECT_ROOT/spec/FEATURES.md")"
WIP_FILE="$(_compat "$AGENTIC_ROOT/session/WIP.md" "$PROJECT_ROOT/.agentic-state/WIP.md")"
```

## CLAUDE.md Template Changes

All direct script calls route through `ag` wrapper:

```markdown
Token-efficient scripts (ALWAYS use these):
- STATUS.md: `bash .agentic/ag status focus "Task"`
- JOURNAL.md: `bash .agentic/ag journal "Topic" "Done" "Next" "Blockers" --why "Reason"`
- HUMAN_NEEDED.md: `bash .agentic/ag blocker add "Title" "type" "Details"`
- FEATURES.md: `bash .agentic/ag feature F-#### status shipped`
- TODO.md: `bash .agentic/ag todo add "Idea"`
```

Key path reference updates:
| Old | New |
|-----|-----|
| `STATUS.md` (root) | `.agentic/STATUS.md` |
| `HUMAN_NEEDED.md` (root) | `.agentic/HUMAN_NEEDED.md` |
| `.agentic-journal/JOURNAL.md` | `.agentic/journal/JOURNAL.md` |
| `.agentic-journal/plans/` | `.agentic/journal/plans/` |
| `spec/*`, `spec/acceptance/*` | `.agentic/spec/*` |
| `.agentic-state/WIP.md` | `.agentic/session/WIP.md` |
| `.agentic-state/AGENTS_ACTIVE.md` | `.agentic/session/AGENTS_ACTIVE.md` |
| `.agentic/PRINCIPLES.md` | `.agentic/lib/PRINCIPLES.md` |
| `.agentic/agents/shared/...` | `.agentic/lib/agents/shared/...` |
| `.agentic/checklists/...` | `.agentic/lib/checklists/...` |
| `.agentic/init/memory-seed.md` | `.agentic/lib/init/memory-seed.md` |
| `.agentic/tools/wip.sh` | `.agentic/lib/tools/wip.sh` (or `bash .agentic/ag wip`) |

Also update: `.cursorrules`, `CODEX.md`, `.codex/instructions.md`, `.github/copilot-instructions.md`, `.agentic/lib/init/memory-seed.md`

## .claude/ Ecosystem Updates

### hooks.json
Move to `.agentic/hooks/claude/hooks.json`. Wrapper scripts **inline bootstrap** (can't assume lib/ exists since Claude Code fires SessionStart automatically on session open).

### .claude/skills/
- Keep committed in `.claude/skills/` (small, ~13KB)
- Regenerate with `generate-skills.sh` during install/upgrade (after lib extraction)
- Skills reference `.agentic/lib/tools/...` and `.agentic/spec/` paths

### settings.local.json
- Contains bash permission patterns like `Bash(bash .agentic/tools/doctor.sh)`
- User-managed, can't auto-migrate safely
- Provide `bash .agentic/ag migrate-settings` helper
- Document path changes in UPGRADING.md

## Git Hooks Strategy

Thin wrappers in `.agentic/hooks/` delegate to `lib/hooks/`:

```bash
#!/usr/bin/env bash
# .agentic/hooks/pre-commit
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$DIR/bootstrap.sh" 2>/dev/null || { echo "Warning: framework not bootstrapped"; exit 0; }
exec bash "$DIR/lib/hooks/pre-commit" "$@"
```

`git config core.hooksPath .agentic/hooks` stays unchanged.

## .gitignore Management

Framework repo's `.gitignore` does NOT ignore `.agentic/lib/`.

`install.sh` adds to user project's `.gitignore`:
```
.agentic/lib/
.agentic/session/
```

## Implementation Phases

### Phase 1a: Introduce paths.sh (non-breaking, ~50 files)
**Goal**: Create the abstraction layer before moving anything.

1. Create `.agentic/lib/paths.sh` returning CURRENT paths (legacy locations)
2. Migrate all tool scripts to source `paths.sh` instead of hardcoding paths:
   - ~26 shell scripts with `../../` parent traversal pattern
   - ~25 scripts with hardcoded `.agentic-journal` / `.agentic-state` references
   - ~18 Python files with hardcoded `spec/` paths (need equivalent path config)
3. Write a **smoke test** that verifies path resolution from every entry point: `ag`, pre-commit hook, SessionStart hook, scaffold.sh
4. Can migrate scripts incrementally (paths.sh with defaults, scripts updated in batches)
5. Verify: `bash tests/validate_framework.sh` passes, all `ag` commands work
6. **Pure addition — nothing moves, nothing breaks**

### Phase 1b: Move framework code into lib/ (framework repo, ~80+ files)
**Goal**: Relocate framework runtime directories under `lib/`.

**CRITICAL: Atomic move requirement** — skills (`.claude/skills/`), claude-hooks, and tool directories MUST be updated in the same commit. Either create thin wrappers at old paths FIRST (separate commit), or move everything + update all references in one commit. Partial moves = broken sessions.

1. Move framework dirs into `lib/`:
   - `tools/` → `lib/tools/`
   - `agents/` → `lib/agents/` (including all subdirs: `claude/`, `codex/`, `copilot/`, `cursor/`, `shared/`, `roles/`, `specialization/`, `context-manifests/`)
   - `workflows/` → `lib/workflows/`
   - `quality/` → `lib/quality/`
   - `quality_profiles/` → `lib/quality_profiles/`
   - `checklists/` → `lib/checklists/`
   - `init/` → `lib/init/`
   - `hooks/` → `lib/hooks/` (implementations)
   - `claude-hooks/` → `lib/claude-hooks/` (implementations)
   - `prompts/` → `lib/prompts/`
   - `schemas/` → `lib/schemas/`
   - `presets/` → `lib/presets/`
   - `support/` → `lib/support/`
   - `token_efficiency/` → `lib/token_efficiency/`
   - `spec/` → `lib/templates/` (RENAMED: these are templates, not project specs)
   - Root docs: `PRINCIPLES.md`, `DEVELOPER_GUIDE.md`, `START_HERE.md`, `README.md`, `FRAMEWORK_MAP.md`, `DIRECT_EDITING.md`, `MANUAL_OPERATIONS.md`, `EMERGENCY.md` → `lib/`
2. `settings.sh`/`settings.py` stay at `lib/` root (already there)
3. Fix all `source` statements — scripts that did `source "$SCRIPT_DIR/../lib/settings.sh"` now do `source "$SCRIPT_DIR/../settings.sh"` (since tools/ is now inside lib/)
4. Create thin wrappers: `bootstrap.sh`, `ag`, `.agentic/hooks/pre-commit`, `.agentic/hooks/claude/*.sh`
5. Verify `hooks.json` discovery path — confirm where Claude Code expects it before moving
6. Update `paths.sh` to return new lib paths
7. Update CLAUDE.md (framework-dev version), `.cursorrules`, `CODEX.md`, `.codex/instructions.md`, `.github/copilot-instructions.md`
8. Regenerate skills via `generate-skills.sh` (same commit as tool moves)
9. Update `validate_framework.sh` (174 path references) and test infrastructure helpers

### Phase 2: Consolidate project files (framework repo, ~30 files + moves)
**Goal**: Move project tracking files, journal, specs, ephemeral state under `.agentic/`.

1. Move tracking files: `STATUS.md` → `.agentic/STATUS.md`, `TODO.md` → `.agentic/TODO.md`, `HUMAN_NEEDED.md` → `.agentic/HUMAN_NEEDED.md`, `CONTRIBUTIONS.md` → `.agentic/CONTRIBUTIONS.md`, `OVERVIEW.md` → `.agentic/OVERVIEW.md`
2. Move journal: `.agentic-journal/` → `.agentic/journal/`
3. Move specs: `spec/` → `.agentic/spec/`
4. Move ephemeral: `.agentic-state/` → `.agentic/session/`
5. Move user extensions: `.agentic-local/` → `.agentic/local/`
6. Update `paths.sh` to return new locations (backward compat still checks old paths)
7. Update `.gitignore` (remove old entries, add `.agentic/session/`)
8. Update `state-files.conf` and `scaffold.sh` for new destinations
9. Update all remaining references in skills, CLAUDE.md, scripts, docs
10. Remove old empty directories (`.agentic-journal/`, `.agentic-state/`, `spec/`)

### Phase 3: Release + Install/Upgrade Pipeline (~15 files)
**Goal**: Create release workflow, update install/upgrade for new layout.

1. Create GitHub Actions workflow to build `agentic-lib-v{VERSION}.tar.gz`
2. Update `remote-install.sh` to download lib tarball + thin wrappers
3. Update `install.sh` for new layout:
   - Extract lib tarball to `.agentic/lib/`
   - Save tarball to `.agentic/`
   - Scaffold tracking files, spec/, journal/, session/, local/
   - Set up hooks
   - Add `.agentic/lib/` and `.agentic/session/` to user's `.gitignore`
   - Run `generate-skills.sh`
4. Update `upgrade.sh` — two-tier migration:
   - **Deterministic (script)**: file moves, tarball extraction, .gitignore updates, directory creation
   - **Agent-driven (LLM)**: format migrations (spec/AC formats, storage changes), content validation, edge cases. Agent uses validation scripts to verify output.
   - **Stale file detection**: LLM agent scans for lingering framework files from older versions (old root-level state files, `.agentic-journal/`, `.agentic-state/`). **Prompts user** before deleting/moving — never silently remove.
   - `ag upgrade` triggers agent-driven migration
5. Add bootstrap tests
6. Test full cycle: install → init → ag commands → commit → upgrade
7. Document migration in UPGRADING.md

## Critical Files

| File | What changes |
|------|-------------|
| `.agentic/lib/tools/ag.sh` (93KB) | Path resolution via paths.sh, new subcommands |
| `.agentic/lib/agents/claude/CLAUDE.md` | All path references (constitution template) |
| `.agentic/lib/tools/upgrade.sh` (40KB) | Layout migration logic |
| `install.sh` | New layout + tarball extraction |
| `remote-install.sh` | Download lib tarball |
| `tests/validate_framework.sh` (3040 lines) | Path assertions |
| `.agentic/lib/tools/generate-skills.sh` | Skill generation with new paths |
| `.agentic/lib/init/state-files.conf` | Template → destination mappings |
| `.agentic/lib/init/scaffold.sh` | Directory creation logic |
| `.agentic/lib/init/memory-seed.md` | Path references for agent memory |
| `.github/workflows/release.yml` | NEW: lib tarball build step |
| `.agentic/lib/settings.sh` | May merge with or delegate to paths.sh |
| CLAUDE.md (framework-dev root) | Path references |
| `.cursorrules`, `CODEX.md` | Path references |
| `.codex/instructions.md`, `.github/copilot-instructions.md` | Path references |

## Verification

1. `bash tests/validate_framework.sh` passes in framework repo
2. Scratch project: full install → `ag start` → `ag implement` → `ag commit` → `ag done`
3. Upgrade path: existing v0.40.0 project upgrades cleanly
4. Bootstrap: delete `.agentic/lib/` in scratch project → first `ag` command re-extracts
5. Git hooks: commits trigger pre-commit through thin wrapper
6. Fresh clone: `git clone` → open in Claude Code → SessionStart hook bootstraps automatically
7. Root clean: only 7 files (CLAUDE.md, .cursorrules, CODEX.md, README.md, AGENTS.md, STACK.md, CONTEXT_PACK.md)
8. `.claude/skills/` reference correct paths
9. Plans accessible at `.agentic/journal/plans/F-XXXX-plan.md` (4 levels, reasonable)

## Root .md File Categorization

The framework repo has 18 root .md files. Here's what happens to each:

**Move into `.agentic/` (tracking files):**
- STATUS.md → `.agentic/STATUS.md`
- TODO.md → `.agentic/TODO.md`
- HUMAN_NEEDED.md → `.agentic/HUMAN_NEEDED.md`
- CONTRIBUTIONS.md → `.agentic/CONTRIBUTIONS.md`
- OVERVIEW.md → `.agentic/OVERVIEW.md`

**Stay at project root (convention/tool requirements):**
- CLAUDE.md (Claude Code requirement)
- CODEX.md (Codex requirement)
- README.md (convention)
- AGENTS.md (multi-agent coordination, referenced in CLAUDE.md)
- STACK.md (project config)
- CONTEXT_PACK.md (architecture snapshot)

**Framework-dev only (stay at root in framework repo, NOT installed to user projects):**
- CHANGELOG.md, CREDITS.md, RELEASING.md, UPGRADING.md
- FRAMEWORK_DEVELOPMENT.md, FRAMEWORK_QUICK_START.md
- SESSION_LOG.md (may be deprecated)

## Risks

| Risk | Mitigation |
|------|------------|
| 792+ internal path references | `paths.sh` abstraction (Phase 1a) + find-and-replace for docs |
| `source "../lib/settings.sh"` breakage | Fix in Phase 1b — paths change when tools/ moves into lib/ |
| Binary tar.gz in git | Small (~250KB), version-named |
| Parallel extraction race | Atomic `mv` with PID-namespaced temp dirs |
| Hooks fire before bootstrap | Thin wrappers inline `bash bootstrap.sh`, fail open if it fails |
| CI/CD needs framework | Document `bash .agentic/bootstrap.sh` as first CI step |
| settings.local.json | `ag migrate-settings` helper + UPGRADING.md |
| Two `spec/` confusion | Eliminated: `lib/templates/` for templates, `.agentic/spec/` for project |
| Mid-migration broken state | Phase 1a creates abstraction FIRST; each sub-phase is independently testable |
| settings.sh is the linchpin | Every script depends on it. Write a structural smoke test verifying path resolution from every entry point (ag, pre-commit, SessionStart, scaffold) |
| Python scripts with hardcoded paths | 18+ Python files reference `spec/` paths; need equivalent path config or CLI args |
| Atomic move requirement | Skills, hooks, tools must move in same commit or wrappers must precede moves |

## Plugin Compatibility (Future)

Claude Code's plugin system (`plugin.json` + `/plugin install`) bundles skills, agents, hooks, and MCP servers. The planned layout is plugin-compatible:
- `.agentic/lib/agents/claude/` skill sources → map to plugin skills
- `.agentic/hooks/claude/` → map to plugin hooks
- `.claude/skills/` (generated) → exactly what a plugin would provide
- **Future**: extract Claude Code layer into a plugin. Core framework stays in `lib/` as tool-agnostic.

## Out of Scope

- Moving STACK.md or CONTEXT_PACK.md into `.agentic/` (staying at root)
- Global framework install — each repo is self-contained
- Auto-update mechanism
- Claude Code plugin distribution (design-compatible, implement later)
