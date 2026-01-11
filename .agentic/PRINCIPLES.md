# Framework Principles

**Purpose**: This document captures the core values and principles that guide the Agentic AI Framework. These principles inform every design decision and help maintain framework coherence as it evolves.

**For New Contributors**: Understanding these principles is essential before proposing changes to the framework.

---

## Core Philosophy

### Sustainable Long-Term Development

**What**: This framework optimizes for projects lasting months or years, not quick prototypes.

**Why**: 
- Complex software takes time to build
- Context windows reset frequently
- Teams and requirements evolve
- AI alone cannot sustain long-term projects

**How**: 
- Durable artifacts survive context resets (CONTEXT_PACK, STATUS, JOURNAL)
- Documentation evolves with code
- Clear project state always visible
- Human-agent partnership, not AI autonomy

**Example**: A 6-month project with 50 features, multiple context resets, and evolving requirements stays coherent because STATUS.md and JOURNAL.md maintain continuity.

**Anti-pattern**: ❌ Optimizing for quick demos that break after a few sessions when context is lost.

---

### Human-Agent Partnership

**What**: Humans and AI agents collaborate as partners, each contributing their strengths.

**Why**:
- Humans have domain knowledge and judgment
- AI has execution speed and consistency
- Neither alone is optimal
- Specs are the collaboration interface

**How**:
- Humans can directly edit specs (FEATURES.md, acceptance criteria)
- Agents honor human edits as source of truth
- No auto-commits without human approval
- Both humans and agents read/write documentation

**Example**: Human adds feature to FEATURES.md with acceptance criteria. Agent reads it, implements using TDD, updates status. Human reviews and accepts.

**Anti-pattern**: ❌ "Agent-driven development" where humans just watch. ❌ Hiding specs from humans in obscure formats.

---

### Context Efficiency Enables Complexity

**What**: Limited context windows are a constraint that shapes every framework decision.

**Why**:
- Reading entire codebases repeatedly is prohibitive
- Context resets would kill projects without strategy
- Token costs matter for sustainability
- Sequential agents need even tighter budgets

**How**:
- Durable artifacts provide maximum context per token
- Structured reading protocols (10-15K token budgets)
- Sequential agents optimize context per role
- Manual operations save tokens for development

**Example**: Research Agent loads 30K tokens (no implementation code). Implementation Agent loads 45K tokens (no research docs). Total 75K vs. 200K for general agent.

**Anti-pattern**: ❌ Reading all files in src/ at session start. ❌ No persistent documentation, re-learning every session.

---

### Green Coding & Environmental Responsibility

**What**: Software should minimize energy consumption and environmental impact through efficient design and implementation.

**Why**:
- Energy-efficient code reduces operational costs
- Sustainable software aligns with global environmental goals
- Efficient code is usually faster, more maintainable code
- Developer responsibility extends to environmental impact
- Green principles often align with performance optimization

**How**:
- Optimize algorithms for computational efficiency (lower complexity)
- Minimize resource usage (memory, CPU cycles, network calls)
- Lazy loading and on-demand resource allocation
- Intelligent scheduling of background tasks (event-driven > polling)
- Profile and optimize energy hotspots
- Design for longevity (reduce need for frequent rewrites)
- Choose energy-efficient hosting and infrastructure

**Example**: 
- Use O(n log n) sort instead of O(n²) for large datasets (less CPU)
- Lazy load images only when visible (less bandwidth, memory)
- Cache API responses to reduce redundant network calls
- Debounce UI updates to reduce unnecessary redraws
- Use WebP instead of PNG (smaller files, less transfer energy)

**Anti-pattern**: 
- ❌ Polling every second when webhooks/events would work
- ❌ Loading entire datasets when pagination would suffice
- ❌ Unoptimized algorithms causing excessive CPU usage
- ❌ Memory leaks forcing server restarts
- ❌ Inefficient database queries causing repeated full table scans

**Connection to Other Principles**:
- **Token Economics**: Efficient code = less compute = lower energy
- **Quality by Design**: Green code is often cleaner, more maintainable
- **Performance**: Energy efficiency and speed usually go hand-in-hand
- **Longevity**: Sustainable design extends software lifecycle

---

### Deterministic Behavior & Enforcement

**What**: Agents should produce consistent, predictable results through verification and gates, not just documentation conventions.

**Why**:
- Documentation can be ignored (agents may skip reading)
- Guidelines can be misunderstood or forgotten
- Compliance varies across agent models and versions
- Critical workflows must be reliable, not "usually" reliable
- Failure should be detected early, not after shipping

**How**:
- **Verification scripts > Documentation**: `wip.sh check` is mandatory, not optional
- **Gates that block > Guidelines that advise**: Pre-commit hooks enforce, checklists advise
- **Explicit protocols > Implicit expectations**: `session_start.md` specifies exact steps
- **Automated checks > Human vigilance**: Hooks validate before commits
- **Structured data > Free text**: YAML frontmatter enables machine validation

**Enforcement Mechanisms**:

1. **Session Start Protocol** (Mandatory):
   - `.agentic/checklists/session_start.md` - FIRST step is `wip.sh check`
   - Detects interrupted work, prevents building on incomplete changes
   - Non-negotiable: WIP check returns exit code 1 if interrupted work found

2. **Commit Gates** (Blocking):
   - `.agentic/hooks/pre-commit-check.sh` - Validates before commit allowed
   - Checks: WIP.md doesn't exist, shipped features have acceptance criteria
   - Exit code 1 blocks commit if validation fails

3. **Feature Completion Protocol** (Validated):
   - `.agentic/workflows/definition_of_done.md` - Explicit checklist
   - `feature.sh` enforces valid status transitions (planned → in_progress → shipped)
   - Never mark "shipped" without tests + acceptance criteria

4. **Token-Efficient Operations** (Append-only):
   - `journal.sh`, `status.sh`, `feature.sh`, `blocker.sh` - Surgical edits
   - Avoid full-file rewrites that waste tokens
   - 40x more efficient than read-modify-write pattern

5. **Recovery Protocol** (Structured):
   - WIP tracking + git diff integration
   - Clear options: Continue | Review | Rollback
   - No guessing about interrupted work state

**Example (Before - Unreliable)**:
```markdown
# agent_operating_guidelines.md
"Agents should update FEATURES.md when completing features."

Result: Some agents do, some forget, some partially update.
Token waste: Full file read (1200 tokens) for status change.
```

**Example (After - Enforced)**:
```bash
# Token-efficient script enforces valid states
bash .agentic/tools/feature.sh F-0005 status shipped
# Validates: status is valid, file format correct
# Updates: Single line, no full read
# Cost: 50 tokens vs. 1200 tokens
# Outcome: Deterministic, always correct

# Pre-commit hook blocks if incomplete
bash .agentic/hooks/pre-commit-check.sh
# Exit 1 if WIP.md exists (work incomplete)
# Exit 1 if shipped features lack acceptance criteria
# Exit 0 only if all gates pass
```

**Why This Matters**:

**Reliability over Convenience**:
- Convenient: "Agents should read session_start.md"
- Reliable: `wip.sh check` returns exit code, blocks if interrupted

**Early Detection**:
- Problem: Agent commits incomplete work, builds on it, compounds errors
- Solution: Pre-commit hook detects WIP.md, blocks commit until complete

**Cross-Agent Consistency**:
- Problem: Different AI models interpret guidelines differently
- Solution: Scripts enforce same behavior regardless of agent

**Token Economics**:
- Problem: Reading JOURNAL.md (2000 tokens) to append entry
- Solution: `journal.sh` appends without read (50 tokens), 40x savings

**Connection to Other Principles**:
- **Context Efficiency**: Token-efficient scripts reduce waste
- **Quality by Design**: Gates prevent shipping incomplete features
- **Human-Agent Partnership**: Scripts enforce contracts reliably
- **Sustainable Long-Term**: Determinism enables scaling to large projects

**Anti-patterns**:
- ❌ "Agents should..." without enforcement (hope-based development)
- ❌ Full file rewrites for single field updates (token waste)
- ❌ Advisory checklists without validation (ignored under pressure)
- ❌ No detection of interrupted work (build on broken foundations)
- ❌ Commit first, validate later (too late to prevent problems)

---

## Token Economics Principles

### Durable Artifacts Prevent Repeated Re-Reading

**What**: Maintain living documents that capture project truth, preventing repeated codebase scanning.

**Why**: Re-reading the same code/docs every session wastes tokens and time.

**How Enforced**:
- CONTEXT_PACK.md: architecture snapshot
- STATUS.md: current state and next steps
- JOURNAL.md: session-by-session progress
- Agents read these FIRST (reading_protocols.md)

**Example**: Instead of reading 50 implementation files, agent reads CONTEXT_PACK.md (1K tokens) to know where auth logic lives, then reads only auth files.

**Anti-pattern**: ❌ Starting every session with "let me read all files in src/". ❌ Empty or stale CONTEXT_PACK.md.

---

### Structured Reading Protocols

**What**: Agents follow explicit token budgets for different reading scenarios.

**Why**: Unstructured reading wastes tokens on irrelevant context.

**How Enforced**:
- reading_protocols.md defines budgets
- Always read: CONTEXT_PACK (500-1K), STATUS (300-800), JOURNAL recent (500-1K)
- Conditional reads based on task
- agent_operating_guidelines.md requires following protocols

**Example**: Implementing F-0005: Read CONTEXT_PACK (1K), STATUS (500), acceptance/F-0005.md (800), relevant TECH_SPEC section (1K) = 3.3K tokens, not 50K.

**Anti-pattern**: ❌ "Load all spec files to understand the project". ❌ Reading entire FEATURES.md when only one feature is relevant.

---

### Manual Operations Save Tokens

**What**: Humans can read documentation directly instead of asking agents, reserving agent sessions for actual development.

**Why**: 
- Faster (immediate)
- Free (zero tokens)
- Full context (no summarization)

**How Enforced**:
- MANUAL_OPERATIONS.md documents quick commands
- grep/cat patterns for instant answers
- Scripts provide project health without agents
- Dashboard views consolidate information

**Example**: `cat STATUS.md && tail -30 JOURNAL.md` answers "what's happening?" in 2 seconds, zero tokens.

**Anti-pattern**: ❌ Asking agent "what's the current status?" when STATUS.md has the answer. ❌ Agent sessions for information retrieval.

---

### Agent Delegation Saves Tokens

**What**: Specialized agents with cheaper models handle specific tasks more efficiently than one powerful agent doing everything.

**Why**:
- Cheap/fast models are ~10x less expensive than powerful ones
- Simple tasks (exploration, lookups) don't need expensive reasoning
- Subagents get fresh, focused context (not full conversation history)
- Parallel execution for independent tasks

**How**:
- Use **tier-based model selection** (not specific model names):
  - Cheap/Fast tier: Exploration, lookups, simple searches
  - Mid-tier: Implementation, testing, reviews
  - Powerful tier: Complex architecture, difficult bugs
- Delegate exploration to explore-agent (cheap/fast)
- Delegate implementation to implementation-agent (mid-tier)
- Create project-specific agents for domain expertise

**Example**: Instead of opus analyzing "where is auth implemented?" → spawn explore-agent with haiku. Saves ~90% tokens.

**Anti-pattern**: ❌ Using the most powerful model for every task. ❌ Hardcoding specific model names (they change frequently).

**Reference**: `.agentic/token_efficiency/agent_delegation_savings.md`

---

### Sequential Agents Optimize Context

**What**: Specialized agents work sequentially, each loading only role-specific context.

**Why**: Research Agent doesn't need implementation code. Implementation Agent doesn't need research findings.

**How Enforced**:
- sequential_agent_specialization.md defines roles and budgets
- Pipeline state file tracks handoffs
- Each agent role has explicit "Loads ✅/❌" list
- STACK.md `pipeline_enabled` controls this

**Example**: 
- Research Agent: 30K tokens (docs, research, no code)
- Planning Agent: 40K tokens (specs, architecture, no implementation)
- Test Agent: 35K tokens (tests, specs, minimal code)
- Total: 105K vs. 200K for general agent

**Anti-pattern**: ❌ Every agent loading entire codebase. ❌ Test Agent reading research documents.

---

## Quality & Testing Principles

### Small Batch Development (NON-NEGOTIABLE)

**What**: Work in small, isolated batches at the FEATURE level. One feature at a time, commit frequently.

**Why (Critical for Long-Term Quality)**:
- **Easy rollback**: Small changes = easy to verify = easy to rollback
- **Known-good checkpoints**: If something goes wrong, most of the software still works
- **Clear ownership**: One feature at a time = unambiguous responsibility
- **Quality assurance**: Frequent commits = smaller, more reviewable changes

**How Enforced**:
- ONE feature at a time per agent (multi-agent teams use worktrees for parallel work)
- MAX 5-10 files per commit (stop and re-plan if more)
- COMMIT when feature's acceptance tests pass
- pre-commit-check.sh warns when batch size exceeds threshold
- Agents check for "in_progress" features before starting new work

**Rules**:
1. Acceptance criteria MUST exist before implementation (even rough)
2. Implement feature → verify with tests → commit
3. Update specs with discoveries (new edge cases, ideas, issues)
4. If >10 files touched for "one feature", stop and re-plan

**STOP and re-plan if**:
- You need to touch >10 files for "one task"
- You can't define any acceptance criteria
- You've been working >1 hour without a commit
- Multiple features are "in progress"

**Example**: Agent implements "user login" feature. It touches 5 files (route, controller, service, test, spec). Tests pass. Commit. Move to next feature.

**Anti-pattern**: ❌ Working on authentication, session management, and password reset all at once. ❌ Commits with 30 files changed. ❌ "I'll commit everything at the end of the day."

---

### Acceptance-Driven Development

**What**: Features are defined by acceptance criteria. AI implements, then tests verify. Specs evolve with discoveries.

**Why**:
- **AI speed**: AI can generate large working chunks quickly - micro-TDD may be slower than needed
- **Discovery process**: Specs are discovered during implementation, not fully known upfront
- **Acceptance tests**: The critical gate that catches regressions and unwanted changes
- **Realistic workflow**: Accommodates the iterative nature of software development

**How Enforced**:
- Acceptance criteria MUST exist before implementation (even if rough)
- AI implements feature (can be large chunk)
- Acceptance tests verify feature works as expected
- Specs updated with discoveries (new edge cases, issues found)
- TDD remains an OPTION for those who prefer it

**The Flow**:
1. Define feature + acceptance criteria (can be rough initially)
2. AI implements feature
3. Write/update tests to verify acceptance criteria
4. Update specs with discoveries (new requirements, edge cases)
5. Commit when acceptance tests pass
6. Move to next feature

**Example**: 
- Acceptance: "User can log in with email/password"
- AI implements login flow (may be 200 lines)
- Write acceptance test: login with valid credentials succeeds
- Discovery: "Need rate limiting for failed attempts" → add to specs
- Tests pass → commit → next feature

**Anti-pattern**: ❌ Starting implementation with no acceptance criteria at all. ❌ Never updating specs when discoveries are made. ❌ Treating TDD as the only valid approach.

---

### Stack-Specific Quality Over Generic

**What**: Quality checks must match the technology stack, not be generic.

**Why**: Every technology has unique failure modes that generic tests miss.

**How Enforced**:
- continuous_quality_validation.md documents this principle
- quality_profiles/ has stack-specific examples
- Agents create quality_checks.sh during init based on STACK.md
- quality_checks.sh runs before commits

**Example**: 
- Audio plugin: pluginval, NaN/Inf detection, CPU/glitch monitoring
- Web app: Lighthouse, bundle size, accessibility
- Backend: Connection pool leaks, slow queries

**Anti-pattern**: ❌ Only running `npm test` for a web app (missing bundle size, a11y, performance). ❌ Same quality script for audio plugin and REST API.

---

### Acceptance Files Are Mandatory

**What**: Every feature in FEATURES.md MUST have a corresponding acceptance criteria file.

**Why**:
- How do agents/humans know when "done" is done?
- Tests pass ≠ solves user problem
- Enables formal validation
- Prevents shipping incomplete features

**How Enforced**:
- agent_operating_guidelines.md: "🚨 CRITICAL: Feature Creation Rule"
- verify.py reports missing acceptance files
- doctor.py checks acceptance file exists
- Agents must create spec/acceptance/F-####.md when defining feature

**Example**: F-0005 defined in FEATURES.md → spec/acceptance/F-0005.md created with testable criteria BEFORE implementation.

**Anti-pattern**: ❌ Feature marked "shipped" with no acceptance file. ❌ Acceptance criteria only in comments or JOURNAL. ❌ "I'll add criteria later".

---

### Shipped ≠ Accepted

**What**: "Shipped" (code complete) and "Accepted" (human validated) are distinct states.

**Why**:
- Code complete ≠ user validated
- Tests can pass but feature doesn't solve real problem
- Human validation is irreplaceable final gate
- Need audit trail of who validated and when

**How Enforced**:
- FEATURES.md has both `Status: shipped` and `Accepted: yes/no` fields
- agent_operating_guidelines.md: "🚨 CRITICAL: Feature Status Workflow"
- Agents mark shipped, humans mark accepted
- accept.sh tool for formal acceptance

**Example**:
```markdown
F-0005: CSV Export
- Status: shipped       ← Tests pass, code committed
- Verification:
  - Accepted: yes       ← Human tested with real data
  - Accepted at: 2026-01-03
```

**Anti-pattern**: ❌ Marking feature "done" without human validation. ❌ Agent auto-accepting features. ❌ `Accepted: yes` set by agent.

---

### Implementation State Must Match Reality

**What**: The `Implementation: State` field in FEATURES.md must accurately reflect whether code exists.

**Why**: Prevents confusion about what's implemented vs. planned.

**How Enforced**:
- agent_operating_guidelines.md: "🚨 CRITICAL: Never leave `State: none` if code exists"
- Agents check this EVERY time updating FEATURES.md
- verify.py can detect mismatches (code exists but State: none)

**Example**: 
- `State: none` → No code written yet
- `State: partial` → Some modules implemented
- `State: complete` → All code written, tests pass

**Anti-pattern**: ❌ `State: none` but `Code: src/export.py` field is filled. ❌ Never updating State field as code is written.

---

### No Untracked Files in Project Directories

**What**: New files must be git tracked or explicitly ignored. Untracked files in project directories cause deployment failures.

**Why**:
- Agents create files but sometimes forget to `git add`
- Untracked files don't get committed → missing from deployment
- Silent failures are worse than loud failures
- Prevention is cheaper than debugging production

**How**:
- Pre-commit hook (check 6/6) warns about untracked files
- Session end checklist includes untracked file review
- Agent guidelines: "After creating any file, always `git add` it"
- `check-untracked.sh` tool for manual verification

**Example**: Agent creates `assets/sounds/click.wav` but forgets to track. Pre-commit warns: "⚠ Untracked files in assets/". Developer adds it before deployment breaks.

**Anti-pattern**: ❌ Assuming all files get tracked automatically. ❌ Ignoring pre-commit warnings about untracked files.

**Reference**: `.agentic/tools/check-untracked.sh`, `.agentic/hooks/pre-commit-check.sh`

---

### Mutation Testing for Critical Code

**What**: Mutation testing verifies tests catch real bugs by mutating code and checking if tests fail.

**Why**: 100% coverage ≠ good tests. Tests might pass but not catch bugs.

**How Enforced**:
- test_strategy.md documents mutation testing
- mutation_test.sh tool available
- Optional (not mandatory for all code)
- Recommended for critical business logic

**Example**: Payment processing function: mutate `amount > 0` to `amount >= 0`. If tests still pass, they don't check zero-amount validation.

**Anti-pattern**: ❌ Mutation testing every file (expensive, low value). ❌ Ignoring low mutation scores for auth/payments. ❌ "100% coverage" but tests never fail.

---

## Human-Agent Collaboration Principles

### Humans Can Edit Specs Directly

**What**: Humans can directly edit FEATURES.md, acceptance criteria, STATUS.md, etc. Agents MUST honor these edits.

**Why**:
- Humans are stakeholders, not just observers
- Faster than explaining changes to agent
- Humans know requirements agents don't
- Specs are collaboration interface

**How Enforced**:
- Specs are markdown (human-readable)
- Specs are visible in root (not hidden)
- agent_operating_guidelines.md: "Check for human edits"
- USER_WORKFLOWS.md documents this workflow

**Example**: Human adds F-0010 to FEATURES.md, creates spec/acceptance/F-0010.md. Tells agent: "Implement F-0010". Agent reads, implements, updates progress.

**Anti-pattern**: ❌ Agents overwriting human changes. ❌ Specs in proprietary format only agents can edit. ❌ "Don't edit files manually, tell the agent".

---

### No Auto-Commits Without Approval

**What**: Agents NEVER commit changes without explicit human approval.

**Why**:
- Humans need to review code quality
- Understand what changed and why
- Catch mistakes before they propagate
- Maintain control over repository

**How Enforced**:
- git_workflow.md: "🚨 CRITICAL RULE FOR AGENTS"
- agent_operating_guidelines.md: "Non-negotiables"
- Agents present changes, ask for approval, then commit
- Exception: User grants blanket approval

**Example**: 
```
Agent: "I've implemented F-0005. Would you like to review before I commit?"
Human: "Show me the changes"
Agent: [presents summary]
Human: "Looks good, commit it"
Agent: [commits]
```

**Anti-pattern**: ❌ Agent auto-committing without showing changes. ❌ "I've committed your changes" (past tense, no approval). ❌ Blanket auto-commit by default.

---

### Easy Choices Reduce Friction

**What**: Complex decisions are presented as simple choices (a/b patterns).

**Why**:
- Reduces analysis paralysis
- Faster decision-making
- Clear options
- Accessible to beginners

**How Enforced**:
- init_playbook.md: "Type 'a' for Core or 'b' for Core+PM"
- Clear explanations of each option
- Single-letter responses
- Good for/Bad for statements

**Example**: 
```
a) Core (Simple Setup)
   - Good for: Small projects, prototypes
   
b) Core + Product Management
   - Good for: Long-term projects, complex products
   
Type 'a' or 'b':
```

**Anti-pattern**: ❌ "Describe your project in detail and I'll recommend a profile". ❌ Forcing users to understand all nuances upfront. ❌ No clear recommendation.

---

### Agent Partnership Not Replacement

**What**: Framework positions AI as partner, not replacement for developers.

**Why**:
- Developers have domain expertise AI lacks
- AI has execution speed developers lack
- Together > either alone
- Sustainable long-term requires both

**How Enforced**:
- All documentation uses "human-agent" language
- Workflows describe both roles
- Humans make decisions, agents implement
- No "AI will do everything" messaging

**Example**: Human defines what to build (PRODUCT.md, acceptance criteria). Agent implements (TDD, code, tests, updates docs). Human validates (acceptance).

**Anti-pattern**: ❌ "Let AI build your project while you sleep". ❌ Hiding all details from humans. ❌ Agent makes all architectural decisions.

---

## Documentation & Maintenance Principles

### Single Source of Truth

**What**: Every piece of information has ONE authoritative location.

**Why**:
- Updates in 1 place, not 3
- Prevents inconsistency
- Easier maintenance
- Clear "where to look"

**How Enforced**:
- Script explanations: ONLY in DEVELOPER_GUIDE.md
- Quick commands: ONLY in DEVELOPER_GUIDE.md (others reference it)
- Cross-references instead of duplication
- Regular refactoring to eliminate duplication

**Example**: doctor.sh explained in detail in DEVELOPER_GUIDE.md. MANUAL_OPERATIONS.md says "See DEVELOPER_GUIDE.md for details" and just shows command.

**Anti-pattern**: ❌ Same script explanation in 3 files. ❌ Updating one place, forgetting the others. ❌ Conflicting information in different docs.

---

### Documentation Must Reflect Reality

**What**: Documentation describes what ACTUALLY works, not aspirations or plans.

**Why**:
- Broken docs are worse than no docs
- Users need reliable information
- Builds trust
- Accurate > complete

**How Enforced**:
- Test workflows in example projects
- Verify scripts actually work
- Fix broken instructions immediately
- Remove outdated references

**Example**: Example projects are real, working code. Scripts are tested. Workflows are validated by running through them.

**Anti-pattern**: ❌ "This script should work" (but hasn't been tested). ❌ Instructions referencing features that don't exist. ❌ Copy-pasted examples that don't run.

---

### DRY Principle for Documentation

**What**: Documentation should not duplicate information (Don't Repeat Yourself).

**Why**:
- Maintenance burden increases linearly with duplication
- Inconsistency creeps in over time
- Single source of truth easier to update
- Long-term sustainability

**How Enforced**:
- Regular reviews for duplication (like we just did)
- Cross-references instead of copying
- Clear document hierarchy
- Refactor when duplication found

**Example**: Quick commands table in DEVELOPER_GUIDE.md. Other docs reference it, don't copy it.

**Anti-pattern**: ❌ Same table in 3 docs. ❌ Copy-pasting large sections between docs. ❌ "It's easier to duplicate than reference".

---

### Maintainability Over Cleverness

**What**: Simple, clear code/docs are preferred over complex "smart" solutions.

**Why**:
- Future you needs to understand it
- New agents need to maintain it
- Debugging is harder than writing
- Long-term > short-term optimization

**How Enforced**:
- Programming standards: "Clear, descriptive names"
- Code review checklist asks "Is this clear?"
- Documentation refactoring for clarity
- Avoid magic or implicit behavior

**Example**: Explicit `if status == "shipped"` is better than clever status enum magic that saves 2 lines but takes 10 minutes to understand.

**Anti-pattern**: ❌ One-liner that does everything. ❌ Clever regex when simple string operations work. ❌ "This is elegant" (but nobody understands it).

---

### Living Documentation Through Automation

**What**: Documentation stays current through agent updates in same commit as code.

**Why**:
- Stale docs are worse than no docs
- Humans forget to update docs
- Automation ensures consistency
- Same commit = always in sync

**How Enforced**:
- agent_operating_guidelines.md: "Documentation Sync Rule (MANDATORY)"
- FEATURES.md updated when implementation changes
- CONTEXT_PACK.md updated when architecture changes
- JOURNAL.md updated every session

**Example**: Agent implements F-0005, updates FEATURES.md (State: complete), updates JOURNAL.md (session summary), commits all together.

**Anti-pattern**: ❌ Code committed, docs updated "later" (never). ❌ README says "not yet implemented" but feature exists. ❌ Stale placeholders.

---

## Modularity & Flexibility Principles

### Modularity Over Monolith

**What**: Framework offers two profiles (Core and Core+PM) instead of one-size-fits-all.

**Why**:
- Small projects don't need heavyweight PM
- External PM tools (Jira, Linear) are valid
- Forcing decisions upfront is wrong
- Different projects have different needs

**How Enforced**:
- STACK.md has `Profile:` field
- agent_operating_guidelines.md checks profile
- Core: minimal ceremony (PRODUCT.md)
- Core+PM: formal tracking (spec/, STATUS.md)

**Example**: 
- Core: Weekend project, prototype, external PM → Use Core
- Core+PM: 6-month product, formal specs needed → Use Core+PM

**Anti-pattern**: ❌ "You must use full PM features for every project". ❌ One profile for all scenarios. ❌ Can't disable unused features.

---

### Opt-In Complexity

**What**: Advanced features are optional, not mandatory.

**Why**:
- Don't overwhelm beginners
- Start simple, add as needed
- Progressive disclosure
- Flexibility for different projects

**How Enforced**:
- Sequential pipeline: `pipeline_enabled: no` by default
- Retrospectives: optional
- Research mode: optional
- Mutation testing: optional
- STACK.md comments explain each feature

**Example**: Start with Core profile. If project grows complex, enable-product-management.sh to add formal specs. If features are complex, enable sequential pipeline.

**Anti-pattern**: ❌ All features enabled by default. ❌ "You should use everything". ❌ No way to disable features.

---

### Easy Upgrade Path

**What**: Projects can upgrade from Core → Core+PM, and from old framework versions → new versions.

**Why**:
- Don't force decisions upfront
- Projects evolve over time
- Don't abandon projects on old versions
- Migration should be easy

**How Enforced**:
- enable-product-management.sh adds PM features
- upgrade.sh upgrades framework version
- Both scripts handle migration safely
- UPGRADING.md documents process

**Example**: Start with Core profile for MVP. After 3 months, project grows: run `enable-product-management.sh`. Agent converts PRODUCT.md into formal specs.

**Anti-pattern**: ❌ No upgrade path (stuck forever). ❌ Manual, error-prone migration. ❌ "Just start over with new profile".

---

### Progressive Disclosure of Complexity

**What**: Framework reveals advanced features gradually, not all at once.

**Why**:
- Beginners are overwhelmed by all options
- Learn essentials first, advanced later
- Documentation hierarchy supports this
- Adoption curve is smoother

**How Enforced**:
- START_HERE.md → DEVELOPER_GUIDE.md → Advanced topics
- init_playbook.md presents simple choices first
- Advanced features marked "optional"
- "Start with 'no', enable after reviewing" comments

**Example**: New user: Install → Initialize (Core) → Use for weeks → Outgrow Core → Enable PM → Learn sequential pipeline → Enable research mode.

**Anti-pattern**: ❌ README lists all 50 features upfront. ❌ Init process asks 20 questions. ❌ No "recommended for beginners" guidance.

---

## Anti-Patterns (What NOT to Do)

### ❌ Don't Duplicate Documentation

**Why Wrong**: Update in 3 places = errors, maintenance burden, inconsistency over time.

**Correct Approach**: Single source of truth with cross-references.

**How to Fix**: Refactor docs to eliminate duplication (like we just did).

---

### ❌ Don't Mark Feature Shipped Without Acceptance File

**Why Wrong**: How do you know when "done" is done? Tests pass ≠ solves problem.

**Correct Approach**: Create acceptance file BEFORE marking shipped. Human validates.

**How to Fix**: agent_operating_guidelines.md CRITICAL rules enforce this.

---

### ❌ Don't Auto-Commit Without Approval

**Why Wrong**: Humans need control over their repository. Code review catches mistakes.

**Correct Approach**: Always ask before committing. Show what changed.

**How to Fix**: git_workflow.md makes this explicit.

---

### ❌ Don't Use Generic Quality Checks for Specialized Domains

**Why Wrong**: Audio plugins crash on NaN/Inf. Web apps leak memory. Each domain has unique failure modes.

**Correct Approach**: Stack-specific quality profiles.

**How to Fix**: continuous_quality_validation.md + quality_profiles/.

---

### ❌ Don't Hide Product Information From Humans

**Why Wrong**: Humans are stakeholders. Specs are collaboration interface.

**Correct Approach**: Keep STATUS.md, spec/, docs/ visible. Only hide .agentic/ (framework internals).

**How to Fix**: Visible product docs, hidden framework.

---

### ❌ Don't Optimize for Quick Demos

**Why Wrong**: Framework is for long-term projects. Context resets would kill projects.

**Correct Approach**: Durable artifacts, session continuity, sustainable practices.

**How to Fix**: CONTEXT_PACK, STATUS, JOURNAL maintain state.

---

### ❌ Don't Force Heavyweight PM on Small Projects

**Why Wrong**: Weekend projects don't need F-#### IDs. External PM tools exist.

**Correct Approach**: Core profile for simple projects. Core+PM when needed.

**How to Fix**: Two profiles with clear use cases.

---

### ❌ Don't Leave Implementation State Inaccurate

**Why Wrong**: `State: none` but code exists → confusion about what's implemented.

**Correct Approach**: Update State field when adding code. Check every time.

**How to Fix**: agent_operating_guidelines.md CRITICAL rule.

---

### ❌ Don't Assume Agents Will "Figure It Out"

**Why Wrong**: Inconsistent behavior, wasted tokens, poor quality.

**Correct Approach**: Explicit guidelines, clear protocols, documented workflows.

**How to Fix**: agent_operating_guidelines.md with detailed instructions.

---

### ❌ Don't Skip Human Validation

**Why Wrong**: Tests pass ≠ user problem solved. Only humans can validate real-world utility.

**Correct Approach**: Shipped ≠ Accepted. Human validation is final gate.

**How to Fix**: FEATURES.md tracks both states separately.

---

## Summary: The Unstated Core Assumption

**This framework assumes**: Complex software takes months or years to build. It requires:
- **Sustained effort** (not quick hacks)
- **Context continuity** (across resets)
- **Human judgment** (AI alone is insufficient)
- **Quality by design** (not afterthought)
- **Living documentation** (stays current)
- **Token efficiency** (enables complexity)

**Therefore**: Every principle optimizes for **sustainable long-term AI-assisted development of real products**, not quick prototypes or demos.

---

## Using These Principles

### For Developers:
- Understand "why" behind framework decisions
- Make choices aligned with principles
- Question features that violate principles

### For Contributors:
- Propose changes consistent with principles
- Reference principles in design discussions
- Challenge principles if context changed (but with strong rationale)

### For New Agents:
- Read this document first
- These principles guide all work
- When uncertain, return to principles
- These values are non-negotiable core

---

**Last Updated**: 2025-01-11  
**Framework Version**: 0.9.7  

**Note**: Principles evolve, but slowly. Major changes to core philosophy require strong justification and community discussion.

