# Examples

This folder contains example projects demonstrating the Agentic Framework.

## Available Examples

### 1. `core_todo_cli/` - Core Profile Example
**Profile**: Core (no formal product management)

A simple Python CLI todo manager showing:
- `PRODUCT.md` for lightweight planning
- Basic project structure without `spec/` or `STATUS.md`
- How agents work in Core mode (ask user for direction)

**Good for**: Small projects, solo developers, prototypes

---

### 2. `core_pm_taskboard/` - Core + Product Management Example
**Profile**: Core + Product Management

A Next.js task board web app showing:
- Full `spec/` directory with formal requirements
- `STATUS.md` for project roadmap
- Feature tracking with F-#### IDs
- Acceptance criteria in `spec/acceptance/`
- Sequential agent pipeline usage (optional)

**Good for**: Long-term projects, teams, complex products

---

## How to Use These Examples

Each example is a standalone project you can explore:

```bash
cd core_todo_cli/        # or core_pm_taskboard/
cat PRODUCT.md           # (Core) or STATUS.md (Core+PM)
cat CONTEXT_PACK.md      # Architecture overview
python3 .agentic/tools/doctor.py  # Check health
```

## Comparing the Profiles

| Feature | Core | Core+PM |
|---------|------|---------|
| Quality standards | ✅ | ✅ |
| Multi-agent | ✅ | ✅ |
| `PRODUCT.md` planning | ✅ | ✅ |
| `STATUS.md` roadmap | ❌ | ✅ |
| `spec/` formal specs | ❌ | ✅ |
| Feature tracking (F-####) | ❌ | ✅ |
| Acceptance criteria | ❌ | ✅ |
| Sequential pipeline | ❌ | ✅ |

## Old Examples

Previous examples (before profile system) are in `old/` for reference.
