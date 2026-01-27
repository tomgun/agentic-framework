# Context Manifests

Context manifests define what files/sections each agent role needs to load.

## Purpose

- **Token efficiency**: Agents load only relevant context (60-80% savings)
- **Focused work**: Subagents don't get distracted by unrelated code
- **Predictable behavior**: Each role has clearly defined information needs

## Usage

Use `context-for-role.sh` to assemble context for a role:

```bash
# Get context for implementation agent working on F-0042
bash .agentic/tools/context-for-role.sh implementation-agent F-0042

# Preview what would be loaded (dry run)
bash .agentic/tools/context-for-role.sh implementation-agent F-0042 --dry-run
```

## Manifest Format

```yaml
role: agent-name
token_budget: 5000              # Max tokens to load
description: What this agent does

required:                        # Always loaded
  - file.md                      # Full file
  - file.md[section]             # Section extraction

optional:                        # Loaded if budget allows
  - file.md

exclude:                         # Never load
  - JOURNAL.md

variables:                       # Can be substituted
  - feature_id                   # e.g., F-0042

section_markers:                 # How to extract sections
  STACK.md:
    build_commands: "## Build"
```

## Available Manifests

| Manifest | Token Budget | Purpose |
|----------|--------------|---------|
| `orchestrator-agent.yaml` | 2K | Coordinate agents |
| `research-agent.yaml` | 3K | Research & investigation |
| `planning-agent.yaml` | 4K | Create plans & criteria |
| `test-agent.yaml` | 4K | Write tests (TDD) |
| `implementation-agent.yaml` | 5K | Write code |
| `review-agent.yaml` | 6K | Code review |
| `spec-update-agent.yaml` | 3K | Update specs |

## Token Budget Guidelines

- **2-3K tokens**: Coordination, simple lookups
- **4-5K tokens**: Focused implementation/testing
- **6K+ tokens**: Review (needs more context)

## Adding New Manifests

1. Copy an existing manifest as template
2. Define required/optional/exclude files
3. Set appropriate token budget
4. Add section markers if using partial file loading
