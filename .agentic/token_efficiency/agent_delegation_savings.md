# Agent Delegation: Fresh Context is the Primary Benefit

**Core Principle**: Subagents work better because they start with fresh, focused context - not because they use cheaper models.

## The Main Benefit: Context Isolation

### Why Fresh Context Matters Most

| Agent Type | Context Size | Quality Impact |
|------------|--------------|----------------|
| Main agent (long session) | 100K+ tokens | Context drift, forgotten details, accumulated confusion |
| Subagent (fresh start) | 5-10K tokens | Focused, clear, precise output |

**The context reset is what makes subagents powerful.**

A subagent with Opus 4.5 and 5K focused context will often outperform a main agent with Opus 4.5 and 100K accumulated context.

### Model Choice is Secondary (And Optional)

You can choose models based on task needs:

| Task Type | Recommended Model | Why |
|-----------|-------------------|-----|
| Quality-critical implementation | Same as main (e.g., Opus) | Best reasoning, context isolation is the benefit |
| Exploration, file search | Cheaper is fine (Haiku) | Simple task, cost savings make sense |
| Research, complex analysis | Same as main (e.g., Opus) | Needs full reasoning capability |
| Mechanical updates | Cheaper is fine (Haiku) | Straightforward, structured task |

**Don't default to cheaper models** - use them when the task is simple, not as a general optimization.

## Context Isolation Savings

When you spawn a subagent, it gets a **fresh, focused context** rather than carrying your entire conversation history.

| Scenario | Main Agent | Subagent | Savings |
|----------|------------|----------|---------|
| 50-message conversation | ~100K tokens context | ~5K tokens focused | ~95% context |
| Large codebase exploration | Full repo context | Just search results | ~80% context |

### 3. Parallel Execution

Multiple subagents can work simultaneously on independent tasks:
- explore-agent: Find auth files
- explore-agent: Find test files  
- research-agent: Look up JWT best practices

All complete faster than sequential execution by main agent.

## When Delegation Saves Tokens

✅ **DO delegate**:
- Exploration tasks (haiku = cheap)
- Documentation lookups (haiku = cheap)
- Independent subtasks (parallel execution)
- Large implementations (focused context)

❌ **DON'T delegate**:
- Tasks needing current conversation context
- Very simple one-liner actions
- Tasks requiring coordination between results

## Quantified Savings

Based on typical usage patterns:

| Workflow | Without Agents | With Agents | Est. Savings |
|----------|---------------|-------------|--------------|
| Feature implementation | 50K tokens | 20K tokens | 60% |
| Codebase exploration | 30K tokens | 5K tokens | 83% |
| Research + implement | 80K tokens | 35K tokens | 56% |

## Best Practices

1. **Always specify model**: `model: haiku` for exploration saves massively
2. **Use explore-agent first**: Find what you need, then hand off to impl-agent
3. **Batch research**: One research-agent call for multiple questions
4. **Keep main agent for coordination**: Main agent decides, subagents execute

## Reference

Based on Claude's usage optimization guidance:
- [Usage Limit Best Practices](https://support.claude.com/en/articles/9797557-usage-limit-best-practices)

See also:
- `.agentic/agents/claude/subagents/` - Agent definitions
- `.agentic/token_efficiency/context_budgeting.md` - Context management

