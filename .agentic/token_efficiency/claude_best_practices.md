# Claude Token Efficiency Best Practices

Based on [Claude's official usage optimization guide](https://support.claude.com/en/articles/9797557-usage-limit-best-practices).

## Caching Benefits (Use These!)

### 1. Project Knowledge Bases

**Claude caches project content** - it doesn't count against limits when reused:

```
Upload to project:
- CONTEXT_PACK.md
- STACK.md
- Key architecture docs
- Reference materials

Every question about these → uses cached content → fewer tokens!
```

**Framework integration**: Our durable artifacts (`CONTEXT_PACK.md`, `STATUS.md`, etc.) are designed to be added to Claude projects for caching.

### 2. Similar Prompts Are Cached

Claude partially caches frequently-used prompts:
- Session start protocols
- Commit checklists
- Feature complete checklists

**Why this helps**: Our standardized checklists benefit from this caching.

### 3. Conversation Context Memory

Claude remembers earlier context in the conversation:
- Use "As mentioned earlier" instead of repeating
- Reference previous code instead of re-showing
- Build on earlier analysis

## Best Practices for Agents

### 1. Plan Conversations

Before starting work:
- What specific task needs to be done?
- Can related tasks be combined?
- What context is needed upfront?

**Framework integration**: `STATUS.md` and session protocols help with planning.

### 2. Be Specific and Concise

- Clear, detailed instructions in each message
- Avoid vague queries requiring clarification
- Include relevant context upfront

**Framework integration**: Our acceptance criteria and feature specs provide clarity.

### 3. Batch Similar Requests

Group related tasks in one message:
```
❌ Bad: 5 separate messages for 5 tests
✅ Good: "Write tests for: auth, login, logout, reset, verify"
```

### 4. Review Before Sending

Take a moment to review for clarity:
- Is the task clear?
- Is context complete?
- Can I combine with other tasks?

## Optimizing for Claude Plans

### Message Length Matters

Longer messages = more usage:
- Use token-efficient scripts for updates
- Don't read/rewrite entire files
- Use append-only operations

### File Attachments

Large attachments use more:
- Upload core docs to project (cached)
- Reference by path instead of content when possible
- Use `grep` and targeted `read_file` instead of reading everything

### Tool Usage

Some tools use more:
- Research/web search costs more
- Artifacts use quota
- Model choice matters (haiku < sonnet < opus)

## Framework Alignment

Our framework is designed for Claude token efficiency:

| Framework Feature | How It Saves Tokens |
|-------------------|---------------------|
| Durable artifacts (CONTEXT_PACK, STATUS) | Add to project for caching |
| Token-efficient scripts | Append-only, no full file reads |
| Specialized agents | Use haiku for simple tasks |
| Session protocols | Standardized = cached prompts |
| Small batch development | Focused context per task |

## References

- [Usage Limit Best Practices](https://support.claude.com/en/articles/9797557-usage-limit-best-practices)
- `.agentic/token_efficiency/agent_delegation_savings.md` - Agent-specific savings
- `.agentic/token_efficiency/context_budgeting.md` - Context management

