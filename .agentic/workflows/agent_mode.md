# Agent Mode: Quality vs Cost Tradeoff

## What is Agent Mode?

Agent mode controls which AI models are used for different types of tasks. This allows you to balance quality against cost based on your project's needs.

**Location**: `agent_mode` setting in `STACK.md`

## Why Does This Matter?

Different tasks have different quality requirements:

1. **Planning** - Sets direction for everything. Bad specs = wasted implementation tokens. Worth investing in quality.

2. **Implementation** - Writing production code. Benefits from good models.

3. **Review** - Code review, testing, refactoring. Catches issues before they ship.

4. **Search** - Finding files, exploring codebase. Mechanical work, cheaper models handle fine.

## Available Modes

| Mode | Best For | Cost |
|------|----------|------|
| `premium` | Production code, quality-critical work | High |
| `balanced` | General development (DEFAULT) | Medium |
| `economy` | Prototyping, exploration, learning | Low |

### Model Selection by Mode

| Mode | planning | implementation | review | search |
|------|----------|----------------|--------|--------|
| `premium` | opus | opus | opus | sonnet |
| `balanced` (default) | opus | sonnet | sonnet | haiku |
| `economy` | sonnet | haiku | haiku | haiku |

### Mode Details

#### `premium` - Best Quality
Best model for planning, implementation, and review. Slightly cheaper for search.

**Use when**: Production code, quality-critical work, complex features.

#### `balanced` (DEFAULT) - Good Balance
Best model for planning (direction matters), mid-tier for implementation and review.

**Use when**: Most projects, general development, good quality at reasonable cost.

#### `economy` - Cost Saving
Mid-tier for planning, cheap for everything else.

**Use when**: Prototyping, learning, tight budget, simple tasks.

## Setting Agent Mode

In your `STACK.md`:

```yaml
## Agent mode (quality vs cost tradeoff)
- agent_mode: balanced  # premium | balanced | economy
```

## Customizing Models

Override default models for any task type in `STACK.md`:

```yaml
## Model customization (optional)
- models:
    planning: opus        # Architecture, specs, critical decisions
    implementation: sonnet # Writing production code
    review: sonnet        # Code review, testing, refactoring
    search: haiku         # Codebase exploration, finding files
```

### Example: Hybrid Configuration

Economy mode but with opus for planning:

```yaml
- agent_mode: economy
- models:
    planning: opus    # Override: use best for direction-setting
```

## Task Type Mapping

The framework maps 25+ specialized agents to these 4 task types:

| Task Type | Agents Mapped |
|-----------|---------------|
| **planning** | planning-agent, orchestrator-agent, domain-agent, api-design-agent, security-agent |
| **implementation** | implementation-agent, refactor-agent, migration-agent, db-agent |
| **review** | review-agent, test-agent, compliance-agent, perf-agent, ux-agent |
| **search** | explore-agent, research-agent, git-agent, documentation-agent |

## Model Tiers (Cross-Platform)

If using non-Claude tools, map to these tiers:

| Tier | Claude | OpenAI | Google |
|------|--------|--------|--------|
| Best | opus | o1, gpt-4-turbo | gemini-ultra |
| Mid-tier | sonnet | gpt-4o | gemini-pro |
| Cheap/Fast | haiku | gpt-4o-mini | gemini-flash |

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
| premium | $0.15-0.40 |

*Costs are illustrative and change frequently. Check current pricing.*

## Best Practices

1. **Start with `balanced`** - Good default for most projects
2. **Use `premium` for production** - When quality matters most
3. **Use `economy` for learning** - When exploring, prototyping, or budget-constrained
4. **Customize when needed** - Override specific task types as needed

## Related Documentation

- `STACK.md` - Where to configure agent_mode
- `.agentic/agents/claude/CLAUDE.md` - Delegation tables
- `.agentic/agents/shared/agent_operating_guidelines.md` - Full delegation guidance
