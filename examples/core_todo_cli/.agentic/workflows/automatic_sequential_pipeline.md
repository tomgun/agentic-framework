# Automatic Sequential Agent Pipeline

**Purpose**: Enable automatic coordination of specialized agents working sequentially on features without manual handoff orchestration.

**Status**: Core framework feature (v0.1.0)

---

## How It Works

### 1. Pipeline State File

**File**: `..agentic/pipeline/F-####-pipeline.md`

Tracks which agents have completed their work and which is next.

```markdown
<!-- format: pipeline-v0.1.0 -->
# Pipeline: F-0042 (User authentication)

## Status
- Current agent: Implementation Agent
- Phase: in_progress
- Started: 2026-01-02 14:00

## Completed Agents
- ✅ Research Agent (2026-01-02 10:30) - 45 min
- ✅ Planning Agent (2026-01-02 11:30) - 60 min  
- ✅ Test Agent (2026-01-02 13:00) - 90 min
- 🔄 Implementation Agent (started 2026-01-02 14:00)

## Pending Agents
- ⏳ Review Agent
- ⏳ Spec Update Agent
- ⏳ Documentation Agent
- ⏳ Git Agent

## Handoff Notes
### Research → Planning
- Recommendation: Auth.js for Next.js
- Research doc: docs/research/auth-strategies-2026-01-02.md
- Decision: OAuth 2.0 + JWT

### Planning → Test
- Feature defined: F-0042 in FEATURES.md
- Acceptance criteria: 6 ACs in spec/acceptance/F-0042.md
- ADR-0005 created
- Test strategy: Unit + Integration + E2E

### Test → Implementation
- Tests written: 19 tests (unit, integration, E2E)
- All tests FAILING (red phase) ✅
- Goal: Make tests pass (green phase)

### Implementation → Review (pending)
- Will contain: Implementation summary, files changed, tests passing
```

---

## Configuration

### STACK.md Settings

Add to your STACK.md:

```yaml
## Sequential agent pipeline (optional)
<!-- See: .agentic/workflows/sequential_agent_specialization.md -->
- pipeline_enabled: yes # yes | no (default: no)
- pipeline_mode: auto # auto | manual (default: manual)
- pipeline_agents: standard # standard | minimal | full
  # standard: Research → Planning → Test → Impl → Review → Spec Update → Docs → Git
  # minimal: Planning → Impl → Review → Git (skip research, test, docs)
  # full: + Debugging, Refactoring, Security, Performance agents as needed
- pipeline_handoff_approval: no # yes | no (require human approval between agents)
- pipeline_coordination_file: ..agentic/pipeline # directory for pipeline state files
```

**Recommended settings**:
- Start with `pipeline_enabled: yes`, `pipeline_mode: manual` (learn the pattern)
- Graduate to `pipeline_mode: auto` once comfortable
- Use `standard` agents for features, `minimal` for simple changes

---

## Agent Role Detection

### How Agents Know Their Role

**Method 1: Explicit human instruction** (manual mode)
```
Human: "Research Agent: investigate auth options for F-0042"
```

**Method 2: Pipeline state** (auto mode)

Agent reads `..agentic/pipeline/F-####-pipeline.md`:
```markdown
## Status
- Current agent: Implementation Agent
- Phase: in_progress
```

Agent sees: "I am the Implementation Agent"

**Method 3: Context clues** (fallback)

Agent checks:
- If research doc missing & feature undefined → Research Agent
- If feature defined but no tests → Test Agent  
- If tests failing → Implementation Agent
- If tests passing but FEATURES.md not updated → Spec Update Agent
- etc.

---

## Automatic Handoff Mechanism

### When Auto Mode Enabled

**Step 1**: Agent completes work

**Step 2**: Agent updates pipeline file:
```markdown
## Completed Agents
- ✅ Implementation Agent (2026-01-02 15:30) - 90 min

## Status
- Current agent: Review Agent
- Phase: ready_for_next
```

**Step 3**: Agent creates handoff note in pipeline file

**Step 4**: Agent signals completion:

**Option A: Human approval** (if `pipeline_handoff_approval: yes`):
```
Implementation Agent: "Work complete. Ready for Review Agent.
Changes: 4 code files, 3 test files, all tests passing ✅
Approve handoff to Review Agent? (yes/no/show changes)"
```

**Option B: Automatic** (if `pipeline_handoff_approval: no`):
```
Implementation Agent: "Work complete. Handing off to Review Agent..."
[System automatically invokes Review Agent with pipeline context]
```

---

## Agent Operating Guidelines Integration

### Updated agent_operating_guidelines.md

Add these rules:

```markdown
## Sequential Pipeline Mode (if enabled)

**At session start**:
1. Check if pipeline mode enabled: `STACK.md` → `pipeline_enabled: yes`
2. If enabled, check for active pipeline: `..agentic/pipeline/F-####-pipeline.md`
3. If pipeline exists:
   - Read pipeline file to determine your role
   - Read handoff notes from previous agent
   - Load ONLY role-specific context (see token budgets)
4. If no pipeline exists but feature assigned:
   - Check if you should start pipeline (create `..agentic/pipeline/F-####-pipeline.md`)
   - Determine starting agent (usually Planning, or Research if unclear)

**During work**:
- Update pipeline file with progress
- Follow role-specific responsibilities (see sequential_agent_specialization.md)
- Create handoff note for next agent when complete

**At completion**:
- Update pipeline file (mark role complete, set next agent)
- If `pipeline_mode: auto` AND `pipeline_handoff_approval: no`:
  - Save all work
  - Signal for next agent invocation
- If `pipeline_handoff_approval: yes` OR `pipeline_mode: manual`:
  - Present summary to human
  - Ask for approval to hand off
  - Wait for human confirmation

**Pipeline file location**:
- Check `STACK.md` → `pipeline_coordination_file` (default: `..agentic/pipeline`)
- File name: `F-####-pipeline.md`

**Context optimization**:
- Load ONLY what your role needs (see token budgets in sequential_agent_specialization.md)
- Do NOT load entire codebase
- Trust handoff notes from previous agent
```

---

## Pipeline Creation

### Starting a Pipeline

**Trigger**: Human assigns feature or agent recognizes new work

**Who starts**: Planning Agent (or Research Agent if investigation needed)

**How**:

1. Create `..agentic/pipeline/` directory if not exists
2. Create pipeline file: `..agentic/pipeline/F-####-pipeline.md`
3. Initialize from template (see below)
4. Begin work as first agent

**Template**:
```markdown
<!-- format: pipeline-v0.1.0 -->
# Pipeline: F-#### ([Feature Name])

## Configuration
- Pipeline mode: [auto | manual] (from STACK.md)
- Agents: [standard | minimal | full] (from STACK.md)
- Handoff approval: [yes | no] (from STACK.md)
- Started: YYYY-MM-DD HH:MM

## Status
- Current agent: [Agent Name]
- Phase: [in_progress | ready_for_next | blocked | complete]
- Last updated: YYYY-MM-DD HH:MM

## Completed Agents
<!-- Agents add themselves here when done -->

## Pending Agents
- ⏳ [Next Agent Name]
- ⏳ [Future Agent Name]
- ...

## Handoff Notes
<!-- Each agent adds handoff note for next agent -->

## Blockers
<!-- Any issues preventing progress -->

## History
<!-- Optional: Detailed log of agent sessions -->
```

---

## Agent Handoff Protocol (Auto Mode)

### Research Agent → Planning Agent

**Research Agent completes**:
```markdown
## Completed Agents
- ✅ Research Agent (2026-01-02 11:00) - 60 min

## Status
- Current agent: Planning Agent
- Phase: ready_for_next
- Last updated: 2026-01-02 11:00

## Handoff Notes
### Research → Planning
**Recommendation**: Auth.js for Next.js OAuth 2.0

**Context for Planning Agent**:
- Read: docs/research/auth-strategies-2026-01-02.md (Recommendation section)
- Requirements: spec/PRD.md (R-0042, R-0043)
- Constraints: spec/NFR.md (NFR-0002 security)

**Decisions made**:
- Auth strategy: OAuth 2.0
- Library: Auth.js
- Session: HTTP-only cookies

**Open questions**:
- Social providers: Which ones?
- Email/password: Also support?
- MFA: v1.0 or defer?

**Token budget**: ~40K (specs + architecture + research summary)
```

**If auto mode**: System invokes Planning Agent automatically

**If manual mode**: Human sees "Research complete. Ready for Planning Agent." and invokes manually

---

### Planning Agent → Test Agent

**Planning Agent completes**:
```markdown
## Completed Agents
- ✅ Research Agent (2026-01-02 11:00) - 60 min
- ✅ Planning Agent (2026-01-02 12:30) - 90 min

## Status
- Current agent: Test Agent
- Phase: ready_for_next

## Handoff Notes
### Planning → Test
**Feature defined**: F-0042 in FEATURES.md (6 acceptance criteria)

**Context for Test Agent**:
- Read: spec/acceptance/F-0042.md (ALL 6 ACs)
- Test framework: Vitest (unit), Playwright (E2E) - STACK.md
- Test patterns: __tests__/auth/*.test.ts (reference)

**Test strategy**:
- Unit: Auth logic (AC1-AC4)
- Integration: API routes (AC5)
- E2E: Login flow (AC6)

**Goal**: All tests FAILING (red phase)

**Token budget**: ~35K (acceptance + test patterns + minimal impl reference)
```

---

### Test Agent → Implementation Agent

**Test Agent completes**:
```markdown
## Completed Agents
- ✅ Research Agent (2026-01-02 11:00) - 60 min
- ✅ Planning Agent (2026-01-02 12:30) - 90 min
- ✅ Test Agent (2026-01-02 14:00) - 90 min

## Status
- Current agent: Implementation Agent
- Phase: ready_for_next

## Handoff Notes
### Test → Implementation
**Tests written**: 19 tests (unit, integration, E2E)
**Test status**: All FAILING (red phase) ✅

**Context for Implementation Agent**:
- Read: Test files (they show EXACTLY what to implement)
  - __tests__/auth/login.test.ts (AC1-AC4, 12 tests)
  - __tests__/api/auth.test.ts (AC5, 4 tests)
  - e2e/auth/login.spec.ts (AC6, 3 tests)
- Architecture: spec/TECH_SPEC.md (Auth section)
- Goal: Make tests pass (green phase)

**Implementation order**:
1. Auth logic (unit tests first)
2. API routes (integration tests)
3. UI components (E2E tests)

**Token budget**: ~50K (tests + acceptance + architecture + related code)
```

---

### Implementation Agent → Review Agent

**Implementation Agent completes**:
```markdown
## Completed Agents
- ✅ Research Agent (2026-01-02 11:00) - 60 min
- ✅ Planning Agent (2026-01-02 12:30) - 90 min
- ✅ Test Agent (2026-01-02 14:00) - 90 min
- ✅ Implementation Agent (2026-01-02 16:00) - 120 min

## Status
- Current agent: Review Agent
- Phase: ready_for_next

## Handoff Notes
### Implementation → Review
**Implementation complete**: All tests passing ✅

**Files changed**:
- lib/auth/login.ts, lib/auth/session.ts (new)
- app/api/auth/[...nextauth]/route.ts (new)
- components/LoginForm.tsx (new)

**Test status**: 19/19 passing (unit 12/12, integration 4/4, E2E 3/3)

**Context for Review Agent**:
- Acceptance: spec/acceptance/F-0042.md (verify all 6 ACs)
- Implementation: Files listed above
- Tests: __tests__/auth/*, e2e/auth/*
- Checklist: .agentic/quality/review_checklist.md

**Review focus**:
- All ACs met?
- Code quality?
- Test coverage?
- Security (auth is sensitive)?

**Token budget**: ~45K (acceptance + implementation + tests + checklists)
```

---

### Review Agent → Spec Update Agent OR Implementation Agent

**If approved**:
```markdown
## Completed Agents
- ✅ Implementation Agent (2026-01-02 16:00) - 120 min
- ✅ Review Agent (2026-01-02 16:30) - 30 min

## Status
- Current agent: Spec Update Agent
- Phase: ready_for_next

## Handoff Notes
### Review → Spec Update
**Review status**: APPROVED ✅

**Summary**:
- All ACs met
- Code quality good
- Test coverage 95%
- No security issues

**Context for Spec Update Agent**:
- Feature: F-0042
- Status change: planned → shipped
- Release: v1.2.0
- Files changed: 4 code, 3 tests
- Lessons: Auth.js integration straightforward

**Token budget**: ~25K (FEATURES.md + STATUS.md + JOURNAL.md)
```

**If changes needed**:
```markdown
## Status
- Current agent: Implementation Agent
- Phase: rework_needed

## Handoff Notes
### Review → Implementation (Rework)
**Review status**: Changes requested ❌

**Issues**:
1. AC3 not met: Password reset missing
2. Security: Passwords in error logs
3. Coverage: LoginForm only 60%

**Required fixes**:
- Remove passwords from logs (CRITICAL)
- Implement password reset OR split to new feature
- Add LoginForm tests

**Token budget**: ~30K (focused on issues, not full context)
```

---

### Spec Update Agent → Documentation Agent OR Git Agent

**Spec Update Agent completes**:
```markdown
## Completed Agents
- ✅ Review Agent (2026-01-02 16:30) - 30 min
- ✅ Spec Update Agent (2026-01-02 17:00) - 30 min

## Status
- Current agent: Documentation Agent
- Phase: ready_for_next

## Handoff Notes
### Spec Update → Documentation
**Specs updated**: FEATURES.md, STATUS.md, JOURNAL.md

**Context for Documentation Agent**:
- Feature: F-0042 (user authentication)
- User-facing: YES (login UI, API)
- Docs needed:
  - API: POST /api/auth/login, /api/auth/logout
  - User guide: Login instructions
  - Architecture: Auth flow diagram

**Token budget**: ~35K (FEATURES + TECH_SPEC + implementation summary + docs/)
```

---

### Documentation Agent → Git Agent

**Documentation Agent completes**:
```markdown
## Completed Agents
- ✅ Spec Update Agent (2026-01-02 17:00) - 30 min
- ✅ Documentation Agent (2026-01-02 17:45) - 45 min

## Status
- Current agent: Git Agent
- Phase: ready_for_commit

## Handoff Notes
### Documentation → Git
**Documentation complete**: All user-facing docs updated

**Files changed**: 15 total (4 code, 3 tests, 5 specs, 3 docs)

**Context for Git Agent**:
- Feature: F-0042
- Git workflow: pull_request (from STACK.md)
- Branch: feature/F-0042
- Commit message: "feat: implement user authentication (F-0042)"

**Token budget**: ~20K (changed files list + STACK.md + JOURNAL.md for commit msg)
```

---

### Git Agent (Final)

**Git Agent completes**:
```markdown
## Completed Agents
- ✅ Documentation Agent (2026-01-02 17:45) - 45 min
- ✅ Git Agent (2026-01-02 18:00) - 15 min

## Status
- Current agent: NONE
- Phase: complete
- Pipeline duration: 7 hours total

## Result
- Commit: abc123def
- PR: #42 (feature/F-0042 → main)
- Status: Awaiting human review

## Handoff Notes
### Git → Human
**Pipeline complete**: F-0042 ready for review

**PR Details**:
- URL: https://github.com/user/repo/pull/42
- Status: Draft
- CI: Running
- Files: 15 changed (+1,405 lines)

**Next steps for human**:
1. Wait for CI checks
2. Review PR diffs
3. Mark "Ready for review"
4. Merge when approved
```

---

## Error Handling & Recovery

### If Agent Fails

**Agent encounters blocker**:
```markdown
## Status
- Current agent: Implementation Agent
- Phase: blocked

## Blockers
- Issue: Cannot implement AC3 (password reset) - unclear requirement
- Escalation: Need human decision
- Options:
  1. Implement basic password reset now
  2. Split AC3 into separate feature (F-0042-b)
  3. Remove AC3 from F-0042 scope

## Handoff Notes
### Implementation → Human
**Blocked on**: AC3 requirement clarification

**Context**:
- Research recommended Auth.js
- Auth.js has password reset, but complex setup
- AC3 says "password reset" but no details in acceptance criteria

**Question**: Implement now (2-3 hours) or defer to separate feature?
```

**Human resolves**:
```
Human: "Split AC3 into F-0042-b (separate feature). Complete F-0042 without password reset."
```

**Pipeline resumes**:
```markdown
## Status
- Current agent: Implementation Agent
- Phase: in_progress (resumed)

## Blockers
- ✅ Resolved: AC3 split into F-0042-b
```

---

### If Pipeline Needs to Restart

**Any agent can request restart**:
```markdown
## Status
- Current agent: Review Agent
- Phase: pipeline_restart_requested

## Handoff Notes
### Review → Planning (Restart)
**Restart reason**: Architecture fundamentally wrong

**Issue**: Implementation used wrong auth library (custom vs Auth.js from research)

**Action**: Restart from Planning Agent
- Re-plan with correct library
- Re-write tests
- Re-implement

**Preserve**: Research docs, PRD, acceptance criteria (still valid)
```

---

## Skip Agent (Optimization)

### When to Skip

**Skip Research** if:
- Technology well-known
- No unclear requirements
- Simple feature

**Skip Test** if:
- Not using TDD mode
- Non-TDD workflow enabled

**Skip Documentation** if:
- Internal-only change
- No user-facing impact
- No API changes

### How to Skip

**Option 1: Configure in STACK.md**:
```yaml
- pipeline_agents: minimal # Skip Research, Test (if not TDD), Documentation
```

**Option 2: Agent decides to skip**:
```markdown
## Completed Agents
- ✅ Planning Agent (2026-01-02 12:00) - 60 min

## Status
- Current agent: Implementation Agent (SKIPPED Test Agent - non-TDD mode)
- Phase: ready_for_next

## Handoff Notes
### Planning → Implementation (Test Agent Skipped)
**Reason for skip**: STACK.md has `development_mode: standard` (not TDD)

**Context for Implementation Agent**:
- Acceptance: spec/acceptance/F-0042.md
- Tests: Write tests AFTER implementation
- Goal: Meet all acceptance criteria
```

---

## Human Intervention Points

### When Human Approval Required

**Always** (if `pipeline_handoff_approval: yes`):
- Between every agent transition

**By default** (even if auto mode):
- Before Git Agent commits
- When agent encounters blocker
- When pipeline restart requested
- When agent suggests skipping another agent

**Never** (unless explicitly configured):
- Within an agent's work
- For minor progress updates

---

## Pipeline Monitoring

### Dashboard Integration

Update `dashboard.sh` to show pipeline status:

```bash
# Active Pipeline
echo "▶ ACTIVE PIPELINE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -d ..agentic/pipeline ]]; then
  ACTIVE=$(find ..agentic/pipeline -name "*.md" -type f | head -1)
  if [[ -n "$ACTIVE" ]]; then
    FEATURE=$(basename "$ACTIVE" | sed 's/-pipeline.md//')
    CURRENT_AGENT=$(grep "^- Current agent:" "$ACTIVE" | sed 's/.*: //')
    PHASE=$(grep "^- Phase:" "$ACTIVE" | sed 's/.*: //')
    echo "Feature: $FEATURE"
    echo "Current: $CURRENT_AGENT ($PHASE)"
    echo "Pipeline: $(basename $(dirname "$ACTIVE"))"
  else
    echo "No active pipeline"
  fi
else
  echo "Pipeline mode not enabled"
fi
echo ""
```

### Tools Integration

**New tool**: `.agentic/tools/pipeline_status.sh`

```bash
#!/usr/bin/env bash
# Show pipeline status for a feature

FEATURE=$1
if [[ -z "$FEATURE" ]]; then
  echo "Usage: bash pipeline_status.sh F-####"
  exit 1
fi

PIPELINE_FILE="..agentic/pipeline/${FEATURE}-pipeline.md"

if [[ ! -f "$PIPELINE_FILE" ]]; then
  echo "No pipeline found for $FEATURE"
  exit 1
fi

cat "$PIPELINE_FILE"
```

---

## Migration from Manual to Auto

### Phase 1: Learn (Manual Mode)

```yaml
- pipeline_enabled: yes
- pipeline_mode: manual
- pipeline_handoff_approval: yes
```

Human invokes each agent explicitly, reviews each handoff.

### Phase 2: Semi-Auto

```yaml
- pipeline_enabled: yes
- pipeline_mode: auto
- pipeline_handoff_approval: yes
```

Agents hand off automatically, but human approves each transition.

### Phase 3: Full Auto

```yaml
- pipeline_enabled: yes
- pipeline_mode: auto
- pipeline_handoff_approval: no
```

Agents work automatically. Human only intervenes for:
- Final commit approval (Git Agent)
- Blockers
- Pipeline errors

---

## Summary

**Automatic sequential agent pipeline enables**:
- ✅ Agents automatically coordinate via pipeline files
- ✅ Context optimization (each agent <50K tokens)
- ✅ Quality through specialization
- ✅ Handoffs without human orchestration (if auto mode)
- ✅ Human oversight at key points (blockers, commits)
- ✅ Error recovery and pipeline restart
- ✅ Agent skipping for optimization
- ✅ Integration with existing workflows (TDD, git, quality)

**Configuration**:
- Enable in STACK.md
- Choose mode: manual (learn) → auto (production)
- Configure approval points
- Select agent set (minimal/standard/full)

**Next steps**:
1. Add pipeline configuration to STACK.template.md
2. Update agent_operating_guidelines.md with pipeline rules
3. Create pipeline monitoring tools
4. Update dashboard.sh to show pipeline status
5. Test with example feature

