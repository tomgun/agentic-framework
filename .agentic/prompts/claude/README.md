# Claude Workflow Prompts for Agentic AI Framework

This directory contains ready-to-use prompts (called "Projects" in Claude) for common workflows when using the Agentic AI Framework.

## How to Use in Claude

### Method 1: Create a Project
1. In Claude, click "Projects" in the sidebar
2. Create a new project for your product
3. Add this repository as context
4. Copy the relevant prompt from this directory
5. Start a conversation with that prompt

### Method 2: Add Custom Instructions
1. In Project settings, add "Custom Instructions"
2. Paste the framework guidelines:
   - Core instruction: "Follow .agentic/agents/shared/agent_operating_guidelines.md"
   - Add specific workflow prompts as needed

### Method 3: Quick Conversation
1. Start a new conversation
2. Upload relevant files (PRODUCT.md, FEATURES.md, etc.)
3. Paste the prompt from this directory

## Available Prompts

### Session Management
- **`session_start.md`** - Start a new coding session
- **`session_end.md`** - End a session with documentation

### Feature Development (Core+PM Mode)
- **`feature_start.md`** - Begin implementing a feature
- **`feature_test.md`** - Create tests (TDD workflow)
- **`feature_complete.md`** - Mark feature complete

### Spec Management (Core+PM Mode)
- **`migration_create.md`** - Create spec migration
- **`spec_update.md`** - Update specs after implementation

### Core Mode
- **`product_update.md`** - Update PRODUCT.md
- **`quick_feature.md`** - Implement simple feature

### Quality & Maintenance
- **`run_quality.md`** - Run quality checks
- **`fix_issues.md`** - Fix linter/test failures
- **`retrospective.md`** - Project retrospective

### Research & Planning
- **`research.md`** - Deep research session
- **`plan_feature.md`** - Plan complex feature

## Claude-Specific Features

### Artifacts
Claude can create "Artifacts" - interactive previews of:
- Code files
- Mermaid diagrams (architecture, feature dependencies)
- HTML/CSS previews
- Documentation

Use Artifacts for:
- Visualizing architecture with Mermaid
- Previewing UI components
- Reviewing documentation drafts

### Projects (Claude Pro)
Projects in Claude Pro provide:
- Persistent context across conversations
- Custom instructions per project
- Automatic file access
- Better long-term memory

**Setup your project:**
1. Create project: "[Your Product Name]"
2. Add custom instructions:
   ```
   I'm working on a project using the Agentic AI Framework.
   Follow .agentic/agents/shared/agent_operating_guidelines.md strictly.
   Use checklists in .agentic/checklists/.
   Prioritize Test-Driven Development.
   Keep documentation updated in the same commit as code.
   ```
3. Add key files as project context:
   - `PRODUCT.md` or `STATUS.md`
   - `spec/FEATURES.md` (if Core+PM mode)
   - `STACK.md`
   - `.agentic/START_HERE.md`

### Extended Thinking Mode
For complex problems, ask Claude to use "extended thinking":
- Better for architecture decisions
- More thorough analysis
- Helpful for debugging tricky issues

Example: "Using extended thinking, help me debug this race condition..."

### Hooks (Advanced)

**Claude Desktop with hooks enabled** can run automated scripts at key lifecycle points:

| Hook | When | Purpose |
|------|------|---------|
| `SessionStart` | Session begins | Show project status, check for `.continue-here.md` |
| `UserPromptSubmit` | First prompt | Auto-inject `.continue-here.md` (no manual "read" needed!) |
| `PostToolUse` | After file edits | Run quick linter checks |
| `PreCompact` | Before context compaction | Save state to `.continue-here.md` |
| `Stop` | Session ends | Remind about uncommitted changes |

**Setup**: See [`.agentic/claude-hooks/README.md`](../../claude-hooks/README.md) for full documentation.

**Benefits**:
- **Zero-touch context recovery**: `.continue-here.md` is auto-injected
- **Real-time quality gates**: Linter runs after code edits
- **Never lose progress**: State saved before context compaction
- **Better workflow discipline**: Reminders about commits and docs

**If hooks aren't available in your Claude Desktop version**: Use the prompts in this directory instead!

## Tips for Claude

- Claude works well with conversational, detailed prompts
- Ask follow-up questions freely
- Request Artifacts for visualizations
- Use Projects feature for continuity
- Claude can read multiple files simultaneously

## Framework Documentation

For full documentation:
- `.agentic/START_HERE.md`
- `.agentic/DEVELOPER_GUIDE.md`
- `.agentic/README.md`

---

**Note:** These prompts are also compatible with Cursor and GitHub Copilot, though some Claude-specific features (Artifacts, Projects) won't be available in other tools.

