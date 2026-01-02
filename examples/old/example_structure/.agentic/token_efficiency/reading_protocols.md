# Reading protocols (token budgeting)

Purpose: maximize development efficiency by minimizing token waste through strategic reading patterns.

## The problem

Context windows are expensive and limited:
- Reading entire codebases repeatedly wastes tokens
- Reading irrelevant files delays actual work
- Without structure, agents repeatedly re-learn the same information

## Solution: structured reading protocol

### Session start budget: ~10-15K tokens for context

Allocate your token budget strategically before writing any code.

## Always read (≈2-3K tokens)

These files provide maximum context per token:

1. **`CONTEXT_PACK.md`** (≈500-1000 tokens)
   - Where to look
   - How to run/test
   - Architecture snapshot
   - Known risks

2. **`STATUS.md`** (≈300-800 tokens)
   - Current focus
   - What's in progress
   - Next steps
   - Known issues

3. **`JOURNAL.md` recent entries** (≈500-1000 tokens)
   - Read last 2-3 session entries
   - Understand recent progress and blockers
   - Avoid repeating failed approaches

**Total: ~2-3K tokens for project state**

## Conditional reads (prioritize ruthlessly)

### When implementing a feature (≈3-5K tokens)

1. **Feature's acceptance criteria** (≈500-1000 tokens)
   - Read `spec/acceptance/F-####.md` for the specific feature
   - Skip other features unless they're dependencies

2. **Relevant spec sections** (≈1-2K tokens)
   - Read only the section of `spec/TECH_SPEC.md` that applies
   - Read only the feature entry in `spec/FEATURES.md`
   - Skip reading entire files

3. **NFRs if applicable** (≈300-500 tokens)
   - Only if feature has `NFRs:` listed
   - Read specific NFR entries, not entire `spec/NFR.md`

### When reading code (≈3-5K tokens)

1. **Start with annotations**
   - Grep for `@feature F-####` to find relevant code
   - Read annotated functions first

2. **Read entry points, not everything**
   - Main function/class implementing the feature
   - Key interfaces/types
   - Skip implementation details until needed

3. **Summarize don't scroll**
   - If a file is >500 lines, read just the relevant function
   - Use grep/search to find specific code
   - Write a summary instead of reading entire files

### Large codebases (>50 files) strategy

Don't read files. Instead:

1. **Use search tools**
   - `grep @feature F-0001` to find implementation
   - Search for function/class names
   - Use file search for imports

2. **Read summaries in CONTEXT_PACK**
   - Should contain: "Module X handles Y, entry point is Z"
   - Update CONTEXT_PACK when you learn structure

3. **Read on-demand**
   - Only read a file when you need to edit it
   - Read minimal context (the function, not the file)

## Stop reading checklist

Stop reading and start coding when you can answer:

✅ **Task clarity**
- [ ] I can describe the change in 1-2 sentences
- [ ] I know the acceptance criteria

✅ **Implementation clarity**
- [ ] I know which files to touch (even if I haven't read them fully)
- [ ] I know what tests to add/update
- [ ] I know the key interfaces/types involved

✅ **Risk awareness**
- [ ] I know the NFRs that apply (if any)
- [ ] I know if there are known issues (from STATUS/JOURNAL)

**If you can't answer these, read more. Otherwise, start coding.**

## Token budget examples

### Small change (bug fix, minor feature) - Total: ~5K tokens
- CONTEXT_PACK.md: 500
- STATUS.md: 300
- JOURNAL.md (recent): 500
- Feature acceptance: 800
- Relevant code (1-2 files): 2000
- Related tests: 1000
- **Buffer**: 900
- **Total**: ~5K

### Medium change (new feature) - Total: ~10K tokens
- CONTEXT_PACK.md: 800
- STATUS.md: 500
- JOURNAL.md (recent): 800
- Feature acceptance: 1000
- TECH_SPEC section: 1500
- NFR entries: 500
- Relevant code (3-5 files): 3000
- Related tests: 1500
- **Buffer**: 400
- **Total**: ~10K

### Large change (refactor, complex feature) - Total: ~15K tokens
- CONTEXT_PACK.md: 1000
- STATUS.md: 600
- JOURNAL.md (recent): 1000
- Multiple feature acceptances: 2000
- TECH_SPEC sections: 2000
- Architecture diagrams: 1000
- ADRs: 1000
- Relevant code (5-10 key files): 5000
- Tests: 1500
- **Buffer**: 900
- **Total**: ~15K

**Beyond 15K**: Consider splitting the task or doing research phase first.

## Heuristics: when to stop reading

### Too much reading:
- Reading entire files "just in case"
- Reading all specs before knowing which is relevant
- Reading implementation details before understanding interfaces
- Re-reading files in the same session

### Too little reading:
- Starting to code without checking acceptance criteria
- Not reading STATUS.md (might work on wrong thing)
- Not checking NFRs for performance/security critical code
- Ignoring recent JOURNAL.md entries (might repeat mistakes)

## Summarization strategies

### File summaries (add to CONTEXT_PACK)

Instead of reading a 1000-line file repeatedly:

```markdown
## Code structure (update when you learn)
- `lib/user.ts` (1200 lines): User domain logic
  - Entry: `UserService` class
  - Key functions: create, authenticate, updateProfile
  - Tests: `lib/user.test.ts`
  - Features: F-0001, F-0003
```

### Architecture summaries

Instead of re-reading TECH_SPEC:

```markdown
## Architecture snapshot
- Style: Modular monolith
- Layers: UI (components/) -> Services (lib/) -> Data (db/)
- Key boundaries: No UI can import db/ directly
- Entry points: app/page.tsx for web routes
```

### Decision summaries

Instead of re-reading ADRs:

```markdown
## Key decisions (from ADRs)
- ADR-0003: localStorage only (no backend yet) - reason: MVP speed
- ADR-0005: React Server Components where possible - reason: performance
```

## Context pruning techniques

### Mid-session pruning

If context gets full:

1. **Remove** what you've implemented (it's now in code/tests)
2. **Keep** STATUS.md current state
3. **Keep** next immediate steps
4. **Summarize** learnings into CONTEXT_PACK

### Session handoff (context reset imminent)

Before context resets:

1. **Update STATUS.md** "Current session state" section
2. **Append to JOURNAL.md** with:
   - What was accomplished
   - Exact next step
   - Any blockers/findings
3. **Update CONTEXT_PACK.md** if you learned new structure
4. **Summarize** don't copy - capture insights, not data

## Agent guidelines

### Starting new session
```
1. Read CONTEXT_PACK.md
2. Read STATUS.md
3. Read last 2 entries in JOURNAL.md
4. Identify the task
5. Read ONLY the acceptance criteria for that task
6. Use search/grep to find relevant code
7. Read minimal code needed
8. Start implementing
```

### Mid-session (running low on tokens)
```
1. Finish current small step
2. Update STATUS.md with progress
3. Append JOURNAL.md entry
4. If learned something structural, update CONTEXT_PACK.md
5. Context reset with fresh session
```

### Before ending session
```
1. Update STATUS.md (always)
2. Append JOURNAL.md (what's done, what's next)
3. Update FEATURES.md (implementation/test status)
4. Update CONTEXT_PACK.md (if structure changed)
```

## Measuring token efficiency

Track these metrics informally:

- **Time to first code edit**: Should be <5 minutes of reading
- **Repeated readings**: If reading same file 3+ times, summarize it
- **Wasted reads**: If you read files you didn't edit, refine search
- **Context resets**: If context resets mid-task, improve handoff

## Examples by scenario

### Scenario: "Implement feature F-0015"

**Good approach** (~8K tokens):
1. Read STATUS.md (check if F-0015 is current focus)
2. Read CONTEXT_PACK.md (where things are)
3. Read spec/acceptance/F-0015.md
4. Grep for `@feature F-0015` (find related code)
5. Read found files (~2-3K tokens)
6. Start implementing

**Bad approach** (~40K tokens, might exceed context):
1. Read entire spec/ directory
2. Read entire codebase to "understand structure"
3. Read all tests
4. Finally start implementing

### Scenario: "Fix bug in search functionality"

**Good approach** (~5K tokens):
1. Read STATUS.md, JOURNAL.md (context)
2. Search codebase for "search" function
3. Read found file + tests
4. Read feature acceptance if mentioned
5. Fix bug

**Bad approach**:
1. Read entire codebase
2. Read all architecture docs
3. Finally find search functionality

### Scenario: "Complex refactor across 20 files"

**Good approach** (split into phases):
1. Phase 1: Research/planning (~15K tokens)
   - Read architecture docs
   - Survey files to change
   - Write refactor plan as task doc
2. Phase 2: Implementation (~10K per step)
   - Small incremental changes
   - Each step reads only affected files
   - Update STATUS.md between steps

**Bad approach**:
1. Try to read all 20 files at once (impossible)
2. Run out of context mid-implementation
3. Lose progress

## Related resources
- Context budgeting overview: `.agentic/token_efficiency/context_budgeting.md`
- Small changes: `.agentic/token_efficiency/change_small.md`
- Dev loop: `.agentic/workflows/dev_loop.md`

