# Plan: Improve Cursor IDE Support

## Context

**Baseline**: PR #229 merged (`862b7b81`) — `cerebrum.yaml` → `project-memory.yaml`, new commands `ag intel remember`/`ag intel memory`/`ag intel decisions`. All new Cursor content must use these names.

**Claude hooks now have 6 enforcement features with NO Cursor equivalent** (must port in Phase 2):
- Plan approval gate (PreToolUse) — blocks code edits without `.plan-approved` or `.plan-review-skipped`
- Spec-before-code (PreToolUse) — blocks impl before spec, separate `.spec-first-skipped` sentinel
- Decision signal detection (UserPromptSubmit) — auto-captures via `ag intel remember`
- Plan content validation (PostToolUse) — advisory, checks plan files mention ACs/tests
- Pending-decision resolution (PostToolUse) — logs when agent acts after pending-decision
- Decision buffer audit (Stop) — warns about uncaptured decisions

**DRY patterns from Claude hooks to reuse**: shared `_EDIT_FILE_PATH` extraction, `_IS_DOC_FILE` classification, single `settings.sh` source per hook invocation.

Cursor has evolved significantly since our integration was last updated. Key changes:
- **`.cursorrules` is deprecated** (since v0.47) — replaced by `.cursor/rules/*.mdc`
- **Cursor now supports Skills** (`.cursor/skills/`) — same open standard as Claude Code
- **Subagent frontmatter changed** — requires `model` (mandatory), `tools` (must include `"parent:*"`), `readonly`, etc. Our agents only have `summary`/`tokens` (non-standard, ignored by Cursor)
- **Native hooks.json** — Cursor expects `.cursor/hooks.json` with 25 hook events; we have shell adapter scripts but never wire them via the JSON config
- **MCP support** — `.cursor/mcp.json` for tool servers

Our current Cursor support: `.cursorrules` (deprecated format), 22 agent files (wrong frontmatter), shell hook adapters (not wired), no skills, no MCP template. Claude Code support is far more mature (hooks.json, 15 skills, proper subagents).

## Plan — 5 Phases (incremental, each shippable independently)

---

### Phase 1: Migrate `.cursorrules` → `.cursor/rules/*.mdc`

**Why**: The most visible gap — `.cursorrules` is deprecated and every Cursor session loads it.

**Create new templates** in `.agentic/lib/agents/cursor/rules/`:

1. **`agentic-core.mdc`** — `alwaysApply: true`
   - Workflow commands, trigger words table, core rules, token-efficient scripts
   - Source: extract from current `cursorrules.txt`
   - Keep under 100 lines (always in context = token-sensitive)

2. **`agentic-code-quality.mdc`** — glob-scoped
   - `globs: ["src/**/*", "lib/**/*", "*.ts", "*.py", "*.js", "*.go", "*.rs"]`
   - Programming standards, testing standards, security-first
   - Source: extract from current `agentic-framework.mdc` "Must-follow behavior"

3. **`agentic-specs.mdc`** — glob-scoped
   - `globs: [".agentic/spec/**/*", ".agentic/work/**/*", "*.yaml"]`
   - Spec-first enforcement, contract format, AC requirements

4. **`agentic-enforcement.mdc`** — intelligent apply
   - `description: "Enforcement hierarchy and gate details — load when discussing hooks, gates, or enforcement"`
   - `alwaysApply: false`, no globs

**Modify**:
- `cursorrules.txt` — add deprecation notice pointing to `.cursor/rules/`
- `setup-agent.sh` `setup_cursor()` — always create `.cursor/rules/`, copy all `.mdc` templates, still generate `.cursorrules` for backward compat

**Critical files**:
- `/workspace/.agentic/lib/agents/cursor/cursorrules.txt` (source content)
- `/workspace/.agentic/lib/agents/cursor/agentic-framework.mdc` (existing .mdc, refactor into split rules)
- `/workspace/.agentic/lib/tools/setup-agent.sh` lines 124-177 (`setup_cursor()`)

---

### Phase 2: Generate `.cursor/hooks.json` + Port Enforcement Parity

**Why**: We have working hook adapters (`enforcement.sh`, `context.sh`) but they're never wired — Cursor doesn't know they exist. Additionally, PR #229 adds significant new enforcement features to Claude hooks that have NO Cursor equivalent:

- **Plan approval gate** (PreToolUse): blocks code edits unless `.plan-approved` or `.plan-review-skipped` sentinel exists
- **Spec-before-code ordering** (PreToolUse): blocks impl files before spec in formal profiles
- **Decision signal detection** (UserPromptSubmit): detects user decisions/instructions/corrections, writes to decision buffer + project-memory.yaml
- **Plan content validation** (PostToolUse): checks plan files mention acceptance criteria + tests
- **Pending-decision resolution** (PostToolUse): when agent acts after pending-decision, logs confirmation
- **Decision buffer audit** (Stop): warns about uncaptured decisions at session end

**Architecture decision**: Extract shared enforcement logic from Claude-specific hooks into common scripts that both Claude and Cursor adapters call, rather than duplicating logic.

**Create**:
1. `.agentic/lib/agents/cursor/hooks.json` — template wiring all 4 events:
```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Shell|file_edit|multi_edit|Write|Edit",
      "hooks": [{
        "type": "command",
        "command": ".agentic/hooks/cursor/enforcement.sh",
        "timeout": 3000
      }]
    }],
    "PostToolUse": [{
      "matcher": "Write|Edit|file_edit|multi_edit",
      "hooks": [{
        "type": "command",
        "command": ".agentic/hooks/cursor/post-tool.sh",
        "timeout": 3000
      }]
    }],
    "SessionStart": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": ".agentic/hooks/cursor/context.sh",
        "timeout": 5000
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": ".agentic/hooks/cursor/context.sh",
        "timeout": 3000
      }]
    }],
    "Stop": [{
      "matcher": ".*",
      "hooks": [{
        "type": "command",
        "command": ".agentic/hooks/cursor/enforcement.sh",
        "timeout": 5000
      }]
    }]
  }
}
```

2. `.agentic/hooks/cursor/post-tool.sh` — NEW: PostToolUse adapter for plan approval detection + plan content validation + pending-decision resolution

3. Optionally: `.agentic/lib/hooks/shared/` — common logic extracted from Claude hooks for plan gates, spec-before-code, decision signals. Called by both Claude and Cursor adapters. (Evaluate during implementation whether the logic is stable enough to share, or whether separate implementations with same behavior are cleaner.)

**Modify**:
- `enforcement.sh` — add plan approval gate + spec-before-code ordering, using same DRY patterns as Claude's PreToolUse (shared `_EDIT_FILE_PATH` extraction, `_IS_DOC_FILE` classification, single `settings.sh` source). Respects both `.plan-review-skipped` and `.spec-first-skipped` sentinels.
- `context.sh` — add decision signal detection (same regex patterns as Claude's UserPromptSubmit) calling `ag intel remember` for auto-capture. Add plan advisory (one-time nudge with `.plan-advisory-shown` sentinel).
- `setup-agent.sh` `setup_cursor()` — copy hooks.json to `.cursor/hooks.json`

**Critical files**:
- `/workspace/.agentic/hooks/cursor/enforcement.sh` (71 lines — to extend)
- `/workspace/.agentic/hooks/cursor/context.sh` (92 lines — to extend)
- `/workspace/.agentic/lib/claude-hooks/PreToolUse.sh` (reference: plan gate lines ~113-140, spec-before-code lines ~143-170, DRY file_path extraction lines ~108-125)
- `/workspace/.agentic/lib/claude-hooks/UserPromptSubmit.sh` (reference: decision signals lines ~214-290, plan advisory lines ~344-360)
- `/workspace/.agentic/lib/claude-hooks/PostToolUse.sh` (reference: plan approval detection lines ~70-95, plan content validation lines ~96-115, pending-decision resolution lines ~118-140)
- `/workspace/.agentic/lib/claude-hooks/Stop.sh` (reference: decision buffer audit lines ~185-215)
- `/workspace/.agentic/lib/tools/setup-agent.sh` lines 124-177

---

### Phase 3: Fix Agent Frontmatter

**Why**: Cursor subagents require `model` (mandatory) and `tools: ["parent:*"]`. Our agents have `summary`/`tokens` which Cursor ignores — subagents can't communicate results back to parent.

**Approach**: Transform during setup (keep source role files agent-agnostic).

**Create** `.agentic/lib/agents/cursor/agent-defaults.yaml`:
```yaml
# Per-agent Cursor frontmatter defaults
# model: "auto" lets Cursor pick; readonly: true for read-only agents
defaults:
  model: auto
  tools: ["parent:*"]
  readonly: false

overrides:
  explore-agent: { readonly: true }
  research-agent: { readonly: true }
  review-agent: { readonly: true }
  plan-critic-agent: { readonly: true }
  plan-advocate-agent: { readonly: true }
  plan-reviewer-agent: { readonly: true }
```

**Modify** `setup-agent.sh` `setup_cursor_agents()`:
- Read agent-defaults.yaml (or hardcode if simpler)
- For each role file: strip old frontmatter → inject Cursor-compatible frontmatter → write to `.cursor/agents/`
- Output format:
  ```yaml
  ---
  model: auto
  tools: ["parent:*"]
  readonly: false
  ---
  # Implementation Agent
  <!-- summary: Write code to make failing tests pass -->
  ```

**Critical files**:
- `/workspace/.agentic/lib/tools/setup-agent.sh` lines 274-310 (`setup_cursor_agents()`)
- `/workspace/.agentic/lib/agents/roles/*.md` (20 source files)

---

### Phase 4: Generate Cursor Skills

**Why**: Cursor now supports `.cursor/skills/<name>/SKILL.md` — same open standard as Claude's `.claude/skills/`. We generate 15 Claude skills but zero Cursor skills.

**Approach**: Since the format is compatible, create a lightweight generator that adapts Claude skills for Cursor.

**Create** `.agentic/lib/tools/generate-cursor-skills.sh`:
- Read Claude skill sources from `.agentic/lib/agents/claude/skills/`
- For each skill: copy SKILL.md, adjust `compatibility` field, adjust tool name references
- Output to `.cursor/skills/<name>/SKILL.md`
- Start with core subset: `session-start`, `implementing-features`, `committing-changes`, `writing-tests`, `fixing-bugs`, `reviewing-code`

**Modify** `setup-agent.sh` `setup_cursor()`:
- Call `generate-cursor-skills.sh` after rules and hooks

**Critical files**:
- `/workspace/.agentic/lib/tools/generate-skills.sh` (reference implementation)
- `/workspace/.claude/skills/` (existing Claude skills to adapt)

---

### Phase 5: MCP Template (low priority)

**Why**: Cursor supports `.cursor/mcp.json` for MCP servers. Framework doesn't expose MCP servers but users may want the template.

**Create** `.agentic/lib/agents/cursor/mcp.json` — empty template with comments:
```json
{
  "mcpServers": {}
}
```

**Modify** `setup-agent.sh` — only copy on explicit `setup-agent.sh cursor-mcp` subcommand, not by default.

---

---

### Specs & Contracts

This work enhances shipped feature **F-025 (Agent System & Instructions)** — it's not a new feature but an upgrade of Cursor support within the existing multi-tool architecture. Per no-feature-inflation rule, add new planned ACs to F-025 via migration.

**New ACs for F-025** (all `status: planned`):

- **AC-006**: `.cursor/rules/` directory with `.mdc` files generated by `setup-agent.sh cursor` (Phase 1)
  - `verify`: `test -d .cursor/rules && ls .cursor/rules/*.mdc | wc -l | grep -q '[1-9]'`
  
- **AC-007**: `.cursor/hooks.json` generated by `setup-agent.sh cursor` and wires enforcement + context hooks (Phase 2)
  - `verify`: `test -f .cursor/hooks.json && jq '.hooks.PreToolUse' .cursor/hooks.json`

- **AC-008**: `.cursor/agents/*.md` files have Cursor-compatible frontmatter (`model`, `tools` fields) (Phase 3)
  - `verify`: `head -5 .cursor/agents/test-agent.md | grep -q 'model:'`

- **AC-009**: `.cursor/skills/` directory with SKILL.md files generated by setup (Phase 4)
  - `verify`: `test -d .cursor/skills && ls .cursor/skills/*/SKILL.md | wc -l | grep -q '[1-9]'`

**Contract file**: `.agentic/spec/contracts/F-025.yaml` — add via `ag contract add-assertion` or migration (since shipped + protected).

**FEATURES.md**: Update F-025 description to mention `.cursor/rules/*.mdc`, hooks.json, skills.

---

### Tests

#### Structural tests (add to `tests/validate_framework.sh`)

Per phase:

**Phase 1** — Rules migration:
- `.agentic/lib/agents/cursor/rules/` directory exists with `.mdc` template files
- Each `.mdc` file has valid YAML frontmatter (contains `description:` field)
- `agentic-core.mdc` has `alwaysApply: true`
- `agentic-code-quality.mdc` has `globs:` field
- `.cursorrules` still exists (backward compat)

**Phase 2** — Hooks JSON + enforcement parity:
- `.agentic/lib/agents/cursor/hooks.json` template exists and is valid JSON
- Template contains `PreToolUse`, `PostToolUse`, `SessionStart`, `UserPromptSubmit`, `Stop` events
- Hook commands reference existing scripts (`.agentic/hooks/cursor/enforcement.sh`, `.agentic/hooks/cursor/context.sh`, `.agentic/hooks/cursor/post-tool.sh`)
- `enforcement.sh` contains plan approval gate (checks `.plan-approved`/`.plan-review-skipped` sentinels)
- `enforcement.sh` contains spec-before-code check (checks token-events.log for prior spec writes)
- `context.sh` contains decision signal detection (regex matching on user prompt)
- `post-tool.sh` exists with plan approval evidence detection + plan content validation
- Stop handler includes decision buffer audit

**Phase 3** — Agent frontmatter:
- After `setup-agent.sh cursor-agents`, agent files in `.cursor/agents/` contain `model:` in frontmatter
- Agent files contain `tools:` with `parent:*`
- Read-only agents (`explore-agent`, `research-agent`, `review-agent`) have `readonly: true`

**Phase 4** — Skills:
- `generate-cursor-skills.sh` exists and is executable
- Generated skills have valid SKILL.md with `name:` and `description:` frontmatter

#### LLM behavioral tests (add to `tests/llm/tests/`)

- **`1XX_cursor_rules_mdc_migration.sh`**: When user says "set up cursor", agent references `.cursor/rules/` not just `.cursorrules`
- **`1XX_cursor_hooks_awareness.sh`**: Agent is aware of `.cursor/hooks.json` for enforcement when discussing Cursor setup

#### Setup script smoke test (new or extend existing)

- Run `setup-agent.sh cursor` in a temp directory → verify all expected output files exist
- Run `setup-agent.sh cursor-agents` in a temp directory → verify agent frontmatter is Cursor-compatible

---

## Out of Scope

- Plugin manifest / Cursor Marketplace (separate effort, requires marketplace registration)
- Async subagent orchestration patterns (orchestrator design, not file generation)
- `/council` integration (requires validation of Cursor-side support)
- Directory-scoped AGENTS.md (nice-to-have for monorepos, not this effort)

## Verification

After each phase:
1. `bash tests/validate_framework.sh` — must pass with new structural assertions added per phase
2. `bash .agentic/lib/tools/setup-agent.sh cursor` in a scratch dir — verify all output files created
3. `bash .agentic/lib/tools/setup-agent.sh cursor-agents` — verify Cursor-compatible frontmatter
4. `jq . .cursor/hooks.json` — valid JSON
5. `ag contract check F-025` — existing ACs pass, new planned ACs show as skipped
6. LLM tests: `bash tests/llm/harness.sh tests/llm/tests/1XX_cursor_*.sh`
7. Manual smoke test: open project in Cursor, verify rules load, hooks fire, agents in @-menu

## Documentation Updates

- `.agentic/lib/agents/cursor/agents-setup.md` — rewrite for new setup outputs
- `FRAMEWORK_QUICK_START.md` — update Cursor setup section
- `docs/INSTRUCTION_ARCHITECTURE.md` — update Layer 1 to show `.cursor/rules/*.mdc`
- Instruction files checklist (CLAUDE.md template, memory-seed) — mention `.cursor/rules/` alongside `.cursorrules`
