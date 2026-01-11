# Token Savings Through Agent Delegation

**Core Principle**: Use the right model for the right task to maximize token efficiency.

## How Specialized Agents Save Tokens

### 1. Model Selection Savings

| Task Type | Without Delegation | With Delegation | Savings |
|-----------|-------------------|-----------------|---------|
| Find file location | expensive model | cheap/fast model | ~90% |
| Search for pattern | mid-tier model | cheap/fast model | ~70% |
| Documentation lookup | expensive model | cheap/fast model | ~90% |
| Implementation | expensive (full context) | mid-tier (focused) | ~50% |

**Why it works**: Cheap/fast models cost ~10x less than expensive ones. Simple tasks don't need expensive reasoning.

**Model tiers** (examples, check current offerings):
- **Cheap/Fast**: Claude Haiku, GPT-4o-mini, Gemini Flash
- **Mid-tier**: Claude Sonnet, GPT-4o
- **Expensive/Powerful**: Claude Opus, GPT-4, o1

### 2. Context Isolation Savings

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

