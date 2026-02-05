# Framework Principles & Values Analysis

## Implicit Principles from Our Conversation

### 1. Documentation & Information Management
- **Single Source of Truth**: Every piece of information has ONE authoritative location
  - *Why*: Prevents inconsistency, easier maintenance
  - *Example*: Script explanations only in DEVELOPER_GUIDE.md
  
- **DRY Principle for Docs**: Documentation should not duplicate
  - *Why*: Updates in one place, not three
  - *Example*: Refactoring we just did (40% less duplication)

- **Documentation Must Reflect Reality**: Docs describe what ACTUALLY works, not aspirations
  - *Why*: Broken docs worse than no docs
  - *Example*: Testing every workflow in example projects

### 2. Mandatory Practices (Agent Guidelines)
- **Acceptance Files Are Mandatory**: NEVER define feature without acceptance criteria file
  - *Why*: How do we know when "done" is done?
  - *Example*: agent_operating_guidelines.md CRITICAL rules added

- **Shipped ≠ Accepted**: Clear distinction between "code complete" and "validated"
  - *Why*: Features need human validation
  - *Example*: Test project had shipped features without acceptance

- **Implementation State Must Match Reality**: Never `State: none` if code exists
  - *Why*: Prevents confusion about what's implemented
  - *Example*: Added explicit check in agent guidelines

### 3. Human-Agent Collaboration
- **Humans Can Edit Specs Directly**: Agents MUST honor human spec edits
  - *Why*: Humans are stakeholders, not just observers
  - *Example*: USER_WORKFLOWS.md documents this extensively

- **No Auto-Commits**: NEVER commit without human approval
  - *Why*: Humans need control over their repository
  - *Example*: Git workflow explicitly requires approval

- **Agent Partnership**: Agents and humans both read/edit specs
  - *Why*: Collaborative development, not agent-only
  - *Example*: Specs are visible, not hidden

### 4. Developer Experience
- **Easy Choices**: Complex decisions made simple (a/b choice for profiles)
  - *Why*: Reduces friction, prevents analysis paralysis
  - *Example*: init_playbook a/b selection

- **Token Economics**: Save tokens by reading docs directly
  - *Why*: Faster, free, gives full context
  - *Example*: MANUAL_OPERATIONS.md entire purpose

- **Fail Fast with Clear Errors**: Tools should report problems clearly
  - *Why*: Faster debugging, less confusion
  - *Example*: doctor.py, verify.py detailed error messages

### 5. Quality & Testing
- **TDD as Default**: Test-Driven Development recommended by default
  - *Why*: Better token economics, forces testability
  - *Example*: STACK.template.md has `development_mode: tdd`

- **Stack-Specific Quality**: Quality checks match your technology
  - *Why*: Generic tests miss technology-specific bugs
  - *Example*: Audio plugin checks vs web app checks

- **Acceptance Criteria Define Done**: Not "it works on my machine"
  - *Why*: Clear, testable definition of success
  - *Example*: spec/acceptance/F-####.md per feature

### 6. Modularity & Flexibility
- **Core vs Core+PM**: Framework should be modular, not monolithic
  - *Why*: Small projects don't need heavyweight PM
  - *Example*: Two profiles with clear use cases

- **Upgrade Path**: Can move from Core → Core+PM anytime
  - *Why*: Don't force decisions upfront
  - *Example*: enable-product-management.sh

- **Portable Framework**: Copy .agentic/ folder, it just works
  - *Why*: No complex installation, no dependencies
  - *Example*: install.sh just copies and configures

### 7. Long-Term Sustainability
- **Maintainability Over Cleverness**: Simple, clear > complex, "smart"
  - *Why*: Future you (or new agent) needs to understand it
  - *Example*: Refactoring docs for single source of truth

- **Version Tracking**: Framework version in every project
  - *Why*: Know what features/behaviors to expect
  - *Example*: STACK.md has framework version

- **Clear Upgrade Path**: Old projects can upgrade to new framework
  - *Why*: Don't abandon projects on old versions
  - *Example*: upgrade.sh tool

### 8. Context Efficiency
- **Sequential Agents Optimize Context**: Specialized agents = smaller context
  - *Why*: 30K tokens vs 200K tokens per agent
  - *Example*: Research Agent doesn't load implementation code

- **Durable Artifacts**: Persistent docs prevent re-reading codebase
  - *Why*: Token efficiency across sessions
  - *Example*: CONTEXT_PACK.md, STATUS.md, JOURNAL.md

### 9. Visibility & Transparency
- **Hidden Framework, Visible Project**: .agentic/ hidden, specs/docs visible
  - *Why*: Optimize for agent work without hiding product info
  - *Example*: Framework in .agentic/, STATUS.md in root

- **Clear Project State**: Always obvious what's happening
  - *Why*: Humans and agents need orientation
  - *Example*: STATUS.md always current

### 10. Practical Over Theoretical
- **Working Code > Perfect Docs**: Ship working features, document later
  - *Why*: Software that works > software that's documented but broken
  - *Example*: Test projects to verify workflows

- **Examples Over Explanations**: Show, don't just tell
  - *Why*: Examples are self-documenting
  - *Example*: example/ projects with real implementations

## What's Already Documented

**In README.md "Design principles"**:
- Feedback loops beat cleverness
- Entropy is real
- Context is expensive
- Agents need a contract

**In various workflow docs**:
- TDD mode benefits
- Git workflow (no auto-commit)
- Token efficiency strategies

## What's MISSING

These critical principles are NOT explicitly documented:
1. ❌ Single source of truth for documentation
2. ❌ Acceptance files are mandatory
3. ❌ Shipped ≠ Accepted distinction
4. ❌ Humans can edit specs directly (agents honor changes)
5. ❌ Implementation state must match reality
6. ❌ Stack-specific quality over generic
7. ❌ Maintainability over cleverness
8. ❌ Easy choices (a/b patterns)
9. ❌ Documentation must reflect reality
10. ❌ Modularity principle (Core vs PM)

## Recommendation

Create **`PRINCIPLES.md`** in `.agentic/` with:

### Structure:
1. **Core Values** (5-7 big principles)
2. **Development Principles** (how we build)
3. **Documentation Principles** (how we document)
4. **Quality Principles** (what "good" means)
5. **Human-Agent Collaboration Principles**
6. **Anti-Patterns** (what NOT to do, and why)

### Format:
```markdown
## Principle Name

**What**: One-sentence description
**Why**: Why this matters
**How**: How it's enforced/implemented
**Example**: Concrete example
**Anti-pattern**: What violation looks like
```

### Links:
- Link from README.md (prominently)
- Link from START_HERE.md
- Link from DEVELOPER_GUIDE.md
- Reference in agent_operating_guidelines.md
- Reference in init_playbook.md

### Benefit:
- ✅ New agents/developers understand "why"
- ✅ Consistent decision-making
- ✅ Framework evolution stays coherent
- ✅ Onboarding is faster
- ✅ Prevents principle drift over time

**Should I create this PRINCIPLES.md?**

