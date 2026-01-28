# Agent Mode: Quality vs Cost Tradeoff

## What is Agent Mode?

Agent mode controls which AI models are used for different types of tasks. This allows you to balance quality against cost based on your project's needs.

**Location**: `agent_mode` setting in `STACK.md`

## Why Does This Matter?

Different tasks have different quality requirements:

1. **Planning/Architecture** - Sets direction for everything. Bad specs = wasted implementation tokens. Worth investing in quality here.

2. **Implementation** - Needs to be good, but benefits less from the most expensive models since the direction is already set.

3. **Search/Exploration** - Mechanical work (finding files, grepping code). Cheaper models handle this fine.

## Available Modes

| Mode | Best For | Cost | Quality |
|------|----------|------|---------|
| `full_steam` | Complex projects, maximum quality | Highest | Best |
| `premium` | Production code, quality-critical work | High | Excellent |
| `balanced` | General development (DEFAULT) | Medium | Very Good |
| `economy` | Prototyping, exploration, learning | Low | Adequate |

### Mode Details

#### `full_steam` - Maximum Quality
Uses the best model (opus) for ALL tasks.

| Task | Model |
|------|-------|
| Planning/specs | opus |
| Implementation | opus |
| Testing | opus |
| Review | opus |
| Search | opus |
| Research | opus |

**Use when**: Complex architecture, critical systems, maximum accuracy needed, cost is not a concern.

#### `premium` - High Quality
Best model for planning AND implementation, cheap for search.

| Task | Model |
|------|-------|
| Planning/specs | opus |
| Implementation | opus |
| Testing | opus |
| Review | opus |
| Search | haiku |
| Research | haiku |

**Use when**: Production code, quality-critical work, budget allows for best implementation quality.

#### `balanced` (DEFAULT) - Good Balance
Best model for planning, mid-tier for implementation, cheap for search.

| Task | Model |
|------|-------|
| Planning/specs | opus |
| Implementation | sonnet |
| Testing | sonnet |
| Review | sonnet |
| Search | haiku |
| Research | haiku |

**Use when**: Most projects, general development.

#### `economy` - Cost Saving
Mid-tier for planning, cheap for everything else.

| Task | Model |
|------|-------|
| Planning/specs | sonnet |
| Implementation | haiku |
| Testing | haiku |
| Review | haiku |
| Search | haiku |
| Research | haiku |

**Use when**: Prototyping, learning, tight budget, simple tasks.

## Setting Agent Mode

In your `STACK.md`:

```yaml
## Agent mode (quality vs cost tradeoff)
- agent_mode: balanced  # full_steam | premium | balanced | economy
```

## Customizing Models

You can override the default models for any task type. This is useful when:

- New models are released that you want to try
- You want to fine-tune for your specific workflow
- You have specific cost constraints
- You want to use different models for different task types

### How to Customize

Uncomment and edit the `models:` section in `STACK.md`:

```yaml
## Model customization (optional)
- models:
    planning: opus        # Architecture, specs, acceptance criteria
    implementation: sonnet # Writing production code
    testing: sonnet       # Writing and running tests
    review: sonnet        # Code review, refactoring suggestions
    search: haiku         # Codebase exploration, file finding
    research: haiku       # Documentation lookup, web search
```

### Example: Hybrid Configuration

Use opus for planning and review, but haiku for everything else:

```yaml
- agent_mode: economy
- models:
    planning: opus    # Override: use best for direction-setting
    review: opus      # Override: use best for quality gates
    # implementation, testing, search, research use economy defaults (haiku)
```

### Example: New Model Testing

Try a new model for implementation:

```yaml
- agent_mode: balanced
- models:
    implementation: claude-3-5-sonnet-20241022  # Try specific version
```

## Model Tiers (Cross-Platform)

If using non-Claude tools, map to these tiers:

| Tier | Claude | OpenAI | Google |
|------|--------|--------|--------|
| Best | opus | o1, gpt-4-turbo | gemini-ultra |
| Mid-tier | sonnet | gpt-4o | gemini-pro |
| Cheap/Fast | haiku | gpt-4o-mini | gemini-flash |

## How Agents Use This

When an agent spawns a subagent (via Task tool), it:

1. Reads `agent_mode` from STACK.md
2. Checks for `models:` overrides
3. Selects the appropriate model for the task type
4. Passes the model to the Task tool

Example delegation:
```
Task tool:
  subagent_type: general-purpose
  model: sonnet  # Based on agent_mode: balanced, task: implementation
  prompt: "Implement the user login feature..."
```

## Cost Comparison

Rough token cost comparison (relative to haiku = 1x):

| Model | Input Cost | Output Cost |
|-------|------------|-------------|
| haiku | 1x | 1x |
| sonnet | 3x | 5x |
| opus | 15x | 75x |

**Example session costs** (10K input, 5K output tokens):

| Mode | Approximate Cost |
|------|------------------|
| economy | $0.01-0.02 |
| balanced | $0.05-0.15 |
| premium | $0.05-0.15 |
| full_steam | $0.20-0.50 |

*Costs are illustrative and change frequently. Check current pricing.*

## Best Practices

1. **Start with `balanced`** - Good default for most projects
2. **Use `full_steam` sparingly** - For complex architecture decisions, critical code
3. **Use `economy` for learning** - When exploring, prototyping, or budget-constrained
4. **Customize when needed** - Don't hesitate to override specific task types
5. **Review periodically** - As new models release, update your configuration

## Verifying Model Selection

To verify agents are using the correct models:

1. **Check Task tool calls** - The `model` parameter shows which model is being used
2. **Review agent output** - Higher-tier models typically produce more detailed output
3. **Run LLM behavioral tests** - See `tests/llm/tests/` for model selection tests

## Related Documentation

- `STACK.md` - Where to configure agent_mode
- `.agentic/agents/claude/CLAUDE.md` - Delegation tables
- `.agentic/agents/shared/agent_operating_guidelines.md` - Full delegation guidance
- `tests/llm/tests/` - Behavioral tests including model selection
