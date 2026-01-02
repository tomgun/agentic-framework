# Review Request: Core vs Core+PM Profiles Implementation

## Context

The Agentic Framework has been restructured to support two profiles:

1. **Core Profile** (Default) - Quality standards, workflows, multi-agent for ANY project
2. **Core + Product Management Profile** (Optional) - Adds formal feature tracking and project management

## What Was Changed

### 1. Framework Structure
- ✅ Moved `agentic/` → `.agentic/` (hidden directory for framework internals)
- ✅ Full framework always present in `.agentic/` (all workflows, tools, templates)
- ✅ Profile determines what gets scaffolded in project, not what's available

### 2. Profile Definitions

**Core Profile Files** (Scaffolded by default):
```
your-project/
├── .agentic/              # Full framework (hidden)
├── STACK.md              # How to build/run (includes profile: core)
├── JOURNAL.md            # Session continuity
├── CONTEXT_PACK.md       # Architecture overview
└── HUMAN_NEEDED.md       # Escalation protocol
```

**Core + Product Management** (Adds these files):
```
your-project/
├── .agentic/              # Same full framework
├── spec/                  # Requirements & features
│   ├── FEATURES.md        # F-#### tracking
│   ├── PRD.md
│   ├── TECH_SPEC.md
│   └── NFR.md
├── STATUS.md              # Project status/roadmap
├── STACK.md              # profile: core+product
├── JOURNAL.md
├── CONTEXT_PACK.md
└── HUMAN_NEEDED.md
```

### 3. Agent Guidelines Updated

**File**: `.agentic/agents/shared/agent_operating_guidelines.md`

**Key changes**:
- ✅ Agents check `profile` field in `STACK.md`
- ✅ Core mode: Clear workflow WITHOUT spec dependencies
- ✅ Core+PM mode: Full spec-driven workflow
- ✅ Resume protocol adapts to profile
- ✅ Non-negotiables conditional on profile

**Core mode workflow**:
1. Ask user for direction (no STATUS.md)
2. Read CONTEXT_PACK.md and JOURNAL.md
3. Work on user's request
4. Update CONTEXT_PACK.md if architecture changes
5. Add to HUMAN_NEEDED.md if stuck
6. Update JOURNAL.md with summary

**Core+PM workflow**:
1. Read STATUS.md (know what to work on)
2. Load specs (FEATURES.md, OVERVIEW.md)
3. Pick feature (F-####)
4. Read acceptance criteria
5. Implement with tests
6. Update FEATURES.md and STATUS.md

### 4. Upgrade Path

**Script**: `.agentic/tools/enable-product-management.sh`

Upgrades Core → Core+PM by:
- ✅ Creating spec/ directory with templates
- ✅ Creating STATUS.md
- ✅ Updating STACK.md profile field
- ✅ Does NOT create CONTEXT_PACK.md or HUMAN_NEEDED.md (already in Core)

### 5. Documentation Updated

- ✅ `README.md` - Explains profiles, when to use each
- ✅ `.agentic/README.md` - Profile descriptions
- ✅ Agent guidelines - Profile-aware behavior

## Questions for Review

### 1. Core Profile Efficiency

**Question**: Can agents work efficiently in Core mode WITHOUT spec/ and STATUS.md?

**What to check**:
- Do agents know what to do? (Ask user vs read STATUS.md)
- Do agents have enough context? (CONTEXT_PACK.md + JOURNAL.md)
- Can agents escalate? (HUMAN_NEEDED.md)
- Is the workflow clear? (See agent guidelines section "If Profile: core")

**Expected behavior in Core**:
- Agent asks: "What should I work on?"
- Agent reads: CONTEXT_PACK.md, JOURNAL.md
- Agent updates: CONTEXT_PACK.md (architecture), HUMAN_NEEDED.md (stuck), JOURNAL.md (summary)
- Agent does NOT: Try to read spec/, STATUS.md, or create feature IDs

### 2. Core+PM Profile Efficiency

**Question**: Does Core+PM mode work as intended?

**What to check**:
- Do agents read STATUS.md first?
- Do agents maintain spec/FEATURES.md?
- Do agents track feature IDs correctly?
- Is sequential pipeline available?

**Expected behavior in Core+PM**:
- Agent reads: STATUS.md, spec/FEATURES.md, spec/OVERVIEW.md
- Agent works on: Features from STATUS.md with F-#### IDs
- Agent updates: spec/FEATURES.md, STATUS.md, CONTEXT_PACK.md
- Agent can use: Sequential pipeline for features

### 3. Profile Selection

**Question**: Is profile selection clear during init?

**What to check**:
- Does scaffold.sh ask about profile? (Not yet implemented)
- Is the choice between Core and Core+PM clear?
- Can user upgrade later easily?

**Current state**:
- ⚠️ scaffold.sh NOT YET updated with profile selection
- ✅ enable-product-management.sh works for upgrades
- ✅ Documentation explains profiles

### 4. Documentation Clarity

**Question**: Do the docs clearly explain when to use each profile?

**What to check**:
- README.md explains Core vs Core+PM?
- When to use each is clear?
- Upgrade path is mentioned?
- Examples show both profiles?

**Current state**:
- ✅ README.md explains profiles
- ✅ When to use each is documented
- ✅ Upgrade path mentioned (enable-product-management.sh)
- ⚠️ Examples not yet updated to show both profiles

## Files to Review

### Critical Files
1. **`.agentic/agents/shared/agent_operating_guidelines.md`** - Agent behavior per profile
2. **`.agentic/tools/enable-product-management.sh`** - Upgrade script
3. **`README.md`** - User-facing documentation
4. **`.agentic/README.md`** - Framework documentation

### Supporting Files
5. **`STACK.md`** (examples) - Should show profile field
6. **`.agentic/init/scaffold.sh`** - Should ask about profile (NOT YET IMPLEMENTED)

## Known Gaps

1. **scaffold.sh NOT updated** - Doesn't ask about profile during init yet
2. **Examples NOT updated** - Don't show Core vs Core+PM profiles
3. **STACK.template.md** - Needs profile field added

## Test Scenarios

### Scenario 1: New Core Project
1. Init project with Core profile
2. Agent should: Ask what to work on, use CONTEXT_PACK.md, not expect spec/
3. Files created: STACK.md (profile: core), JOURNAL.md, CONTEXT_PACK.md, HUMAN_NEEDED.md

### Scenario 2: Core → Core+PM Upgrade
1. Start with Core project
2. Run: `bash .agentic/tools/enable-product-management.sh`
3. Files added: spec/, STATUS.md
4. STACK.md updated: profile: core → core+product
5. Agent should: Now read STATUS.md, maintain spec/

### Scenario 3: New Core+PM Project
1. Init project with Core+PM profile
2. Agent should: Read STATUS.md, maintain specs, track features
3. Files created: All Core files + spec/ + STATUS.md

## Success Criteria

✅ **Agents work efficiently in both modes**
✅ **Profile selection is clear**
✅ **Upgrade path works smoothly**
✅ **Documentation is clear and complete**
✅ **No missing file errors in either mode**

## Next Steps (If Issues Found)

1. Fix agent guidelines if behavior unclear
2. Update scaffold.sh with profile selection
3. Update examples to show both profiles
4. Add profile field to STACK.template.md

---

**Reviewer**: Please test both profiles and report any issues or confusion!

