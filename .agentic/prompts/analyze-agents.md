# Analyze Project for Specialized Agents

**When to use**: After project setup, or when tackling new domains.

**Tell the agent**:

> Analyze this project and suggest specialized subagents that would help. Consider the domain, technology, business model, and what expertise would be valuable.

---

## What the Agent Should Consider

### Technical Domain
- What specialized knowledge does this project require?
- Are there academic/research aspects? (→ scientific-research-agent)
- Complex architecture decisions? (→ architecture-agent)
- Cloud-specific expertise needed? (→ cloud-expert-agent)
- Performance-critical code? (→ performance-agent)

### Product Type
- Does it have a UI? (→ design-agent, accessibility-agent)
- Is it user-facing? (→ ux-research-agent)
- Is it a game? (→ game-design-agent, playtest-agent)
- Is it audio/music? (→ dsp-expert-agent)

### Business Context
- Is it commercial? (→ monetization-agent, marketing-agent)
- Does it need growth? (→ growth-agent, analytics-agent)
- Is it B2B? (→ enterprise-sales-agent)
- Does it handle payments? (→ billing-agent, compliance-agent)

### Compliance & Safety
- Handles user data? (→ privacy-agent, gdpr-agent)
- Financial data? (→ security-agent, audit-agent)
- Healthcare? (→ hipaa-agent)
- Safety-critical? (→ safety-agent)

---

## Output Format

Create: `.agentic/project-agents.md`

```markdown
# Project-Specific Agents

Based on analysis of [project name]:

## Recommended Agents

### [Agent Name]
- **Purpose**: [What this agent does]
- **Why needed**: [Specific project context that requires this]
- **When to use**: [Trigger conditions]
- **Key context**: [What this agent should read]

### [Agent Name]
...

## Agent Definitions

See `.agentic/agents/roles/` for templates.
To create a new agent: `bash .agentic/tools/create-agent.sh [name]`
```

---

## Example Agents by Context

### For Commercial Products
- **monetization-agent**: Pricing strategies, payment flows, conversion optimization
- **marketing-agent**: Positioning, messaging, growth channels
- **analytics-agent**: Metrics, funnels, user behavior

### For User-Facing Apps
- **ux-research-agent**: User interviews, usability testing, personas
- **accessibility-agent**: WCAG compliance, screen reader support
- **localization-agent**: i18n, cultural adaptation

### For Technical Domains
- **scientific-research-agent**: Papers, benchmarks, algorithms
- **architecture-agent**: System design, patterns, scalability
- **security-agent**: Threat modeling, penetration testing, compliance

### For Specific Industries
- **healthcare-agent**: HIPAA, medical device regulations
- **fintech-agent**: PCI-DSS, financial regulations
- **gaming-agent**: Game design, monetization (F2P, gacha), ratings

---

## Reference Examples

See `.agentic/agents/roles/` for example agent definitions:
- `scientific_research_agent.md` - How to gather academic sources
- `architecture_agent.md` - How to make design decisions
- `cloud_expert_agent.md` - How to provide platform expertise

Use these as templates for creating project-specific agents.
