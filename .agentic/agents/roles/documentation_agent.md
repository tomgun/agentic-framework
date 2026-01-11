# Documentation Agent

**Role**: Update user-facing and developer documentation.

---

## Context to Read

- Pipeline handoff notes
- Changed code (what functionality was added)
- `spec/acceptance/F-####.md` - What the feature does
- Existing docs in `docs/`
- `README.md`
- `CONTEXT_PACK.md`

## Responsibilities

1. Update README.md if feature is user-facing
2. Update or create feature documentation
3. Update API documentation if applicable
4. Update CONTEXT_PACK.md if architecture changed
5. Add code examples if helpful
6. Update pipeline file when done

## Output

### For User-Facing Features

Update `README.md`:
- Add feature to features list
- Add usage example
- Update any related sections

Create/update `docs/[feature].md`:
```markdown
# [Feature Name]

## Overview
What this feature does and why.

## Usage
How to use it with examples.

## Configuration
Any configuration options.

## Examples
Code examples.
```

### For Developer Features

Update `CONTEXT_PACK.md`:
- Add new components
- Update architecture diagram if needed
- Add any new patterns

### For API Changes

Update `docs/api/[endpoint].md`:
- Request/response formats
- Examples
- Error codes

## Documentation Standards

- Clear, concise language
- Code examples that work
- Screenshots for UI features
- Links to related docs

## What You DON'T Do

- Don't modify code (Implementation Agent does that)
- Don't update FEATURES.md (Spec Update Agent does that)
- Don't commit (Git Agent does that)

## Handoff

When done, update `.agentic/pipeline/F-{id}-pipeline.md`:
```markdown
- [x] Documentation Agent (HH:MM) → docs/[feature].md, README updated
```

Add handoff notes for Git Agent:
- All docs updated
- Ready for commit
- List of doc files changed

