# Spec Migrations (Optional)

**Purpose**: Track the evolution of specs as atomic changes, complementing the current-state specs with a historical truth that helps AI agents work with smaller context windows.

**Credits**: 
- **Migration concept**: Arto Jalkanen - Event sourcing for specs, atomic operations for better AI context windows
- **Hybrid approach**: Tomas Günther & Arto Jalkanen - Maintaining both current-state (FEATURES.md) and historical truth (migrations) as complementary systems

---

## Philosophy: Two Truths, One System

### Current Truth (What we have now)
- `spec/FEATURES.md` - Current state of all features
- `spec/PRD.md` - Current product requirements
- `spec/TECH_SPEC.md` - Current architecture

**Purpose**: Human-readable snapshot of "what the system does now"

### Historical Truth (New: Migrations) ⭐
- `spec/migrations/001_initial_features.md`
- `spec/migrations/002_add_authentication.md`
- `spec/migrations/003_refactor_payment.md`

**Purpose**: AI-readable log of "how we got here" in small, atomic steps

---

## Why Migrations? (Arto's Insight)

### The Problem
As projects grow, spec files become massive:
- `FEATURES.md` with 100+ features = 5000+ lines
- AI struggles with large context
- Hard to understand what changed and why
- Loses history of decisions

### The Solution
**Event sourcing for specs**:
- Each change is a small migration (50-200 lines)
- AI reads relevant migrations, not entire spec
- Natural audit trail of decisions
- Can regenerate entire spec history
- Smaller context windows = better AI performance

**Analogy**: Like database migrations, but for product specs!

---

## When to Use Migrations

### ✅ **Use migrations when:**
- Project has 50+ features (specs getting large)
- Multiple agents working in parallel
- Need clear audit trail of decisions
- Want to understand "why" not just "what"
- Planning long-term project (years)

### ❌ **Skip migrations when:**
- Small project (<20 features)
- Rapid prototyping phase
- Simple spec files (under 1000 lines)
- Single developer, no team

---

## File Structure

```
spec/
├── migrations/
│   ├── README.md              ← This file
│   ├── _index.json            ← Auto-generated migration registry
│   ├── 001_initial_features.md
│   ├── 002_add_user_auth.md
│   ├── 003_shopping_cart.md
│   ├── 004_payment_integration.md
│   └── ...
├── FEATURES.md                ← Current state (can be generated or manual)
├── PRD.md                     ← Current requirements
└── TECH_SPEC.md               ← Current architecture
```

---

## Migration File Format

### Template Structure

```markdown
<!-- migration-id: 042 -->
<!-- date: 2026-01-04 -->
<!-- author: agent-claude | human-tomas -->
<!-- type: feature | refactor | bugfix | deprecation | architectural -->

# Migration 042: Add Real-Time Notifications

## Context & Why
Brief explanation of the problem or opportunity this addresses.

**Business need**: Users need instant updates without refreshing
**Technical driver**: Improve user engagement, reduce support tickets

## Changes
Atomic list of specific changes made to specs:

### Features Added
- F-0042: Real-time notification system
  - WebSocket connection manager
  - Notification UI component
  - Backend event integration

### Features Modified
- F-0010: User Dashboard
  - Now displays real-time notifications

### Features Deprecated
- (none)

## Dependencies
- **Requires**: Migration 038 (WebSocket infrastructure)
- **Blocks**: Migration 045 (Push notifications on mobile)
- **Related**: ADR-0005 (WebSocket vs Server-Sent Events decision)

## Acceptance Criteria
How to verify this change works:
- [ ] User receives notification within 2 seconds of event
- [ ] Works offline (queues notifications, delivers on reconnect)
- [ ] Max 100 notifications stored locally
- [ ] User can dismiss or mark as read

## Implementation Notes
Guidance for developers:
- Use Socket.io library (already in stack)
- Store notifications in Redux `notifications` slice
- Emit events from backend: `notification.new`, `notification.read`

## Rollback Plan
If this needs to be undone:
- Remove F-0042 from FEATURES.md
- Disconnect WebSocket notification handler
- UI falls back to polling (existing behavior)

## Related Files
Files affected by this migration:
- `spec/FEATURES.md` - Added F-0042
- `spec/NFR.md` - Added NFR-0015 (2s latency requirement)
- `spec/TECH_SPEC.md` - Updated WebSocket usage section
```

---

## Migration Types

### 1. **feature** - New functionality
- Adds new features to FEATURES.md
- Most common type

### 2. **refactor** - Restructuring without changing behavior
- Reorganizes features
- Clarifies relationships
- Updates documentation

### 3. **bugfix** - Corrects spec errors
- Fixes incorrect acceptance criteria
- Updates feature status
- Corrects dependencies

### 4. **deprecation** - Removes features
- Marks features as deprecated
- Documents removal rationale
- Migration path for users

### 5. **architectural** - Major system changes
- Affects TECH_SPEC.md
- Large-scale reorganization
- Technology stack changes

---

## Working with Migrations

### Creating a Migration

```bash
# Manual
bash .agentic/tools/migration.sh create "Add real-time notifications"

# Output: spec/migrations/042_add_realtime_notifications.md
```

### Listing Migrations

```bash
bash .agentic/tools/migration.sh list

# Shows:
# 001 - initial_features (2025-12-01, agent-claude)
# 002 - add_user_auth (2025-12-05, human-tomas)
# 003 - shopping_cart (2025-12-10, agent-claude)
# ...
```

### Viewing a Migration

```bash
bash .agentic/tools/migration.sh show 42

# Displays: spec/migrations/042_add_realtime_notifications.md
```

### Regenerating Current State (Optional)

If you want to auto-generate FEATURES.md from migrations:

```bash
bash .agentic/tools/migration.sh apply

# Reads all migrations in order
# Generates fresh spec/FEATURES.md
```

**Note**: This is optional! You can maintain FEATURES.md manually and use migrations as a complementary history.

---

## Agent Workflow with Migrations

### When Adding a Feature

**Old workflow**:
```
1. Agent reads entire FEATURES.md (5000 lines)
2. Adds new feature F-0042
3. Updates FEATURES.md
```

**New workflow with migrations**:
```
1. Agent reads recent migrations (last 5, ~500 lines)
2. Creates migration/042_add_notifications.md (100 lines)
3. Updates FEATURES.md (or snapshot is auto-generated)
```

**Context saved**: 4500 lines! AI focuses on atomic change.

### When Understanding Context

**Agent needs to understand payment flow**:

**Old**: Read entire FEATURES.md, search for payment-related features

**New**: 
```bash
bash .agentic/tools/migration.sh search "payment"

# Shows:
# 004 - payment_integration
# 012 - payment_refactor
# 028 - payment_security_update
```

Agent reads 3 focused migrations instead of entire spec.

---

## Migration Index (`_index.json`)

Auto-generated registry of all migrations:

```json
{
  "version": "1.0",
  "last_migration": 42,
  "migrations": [
    {
      "id": 1,
      "title": "Initial features",
      "file": "001_initial_features.md",
      "date": "2025-12-01",
      "author": "agent-claude",
      "type": "feature"
    },
    {
      "id": 42,
      "title": "Add real-time notifications",
      "file": "042_add_realtime_notifications.md",
      "date": "2026-01-04",
      "author": "agent-claude",
      "type": "feature",
      "dependencies": [38],
      "blocks": [45]
    }
  ]
}
```

---

## Benefits (Arto's Vision)

### 1. **Smaller Context Windows**
- Each migration: 50-200 lines
- AI reads 3-5 migrations, not 5000-line spec
- Less confusion, better focus

### 2. **Audit Trail**
- See why decisions were made
- Who made them (human or agent)
- When they happened

### 3. **Reproducibility**
- Replay migrations to regenerate system
- Useful for rebuilding with new tech in 5 years
- Clear evolution path

### 4. **Parallel Work**
- Multiple agents create migrations simultaneously
- Merge conflicts are easier (small files)
- Natural work separation

### 5. **Documentation**
- Current state (FEATURES.md) for humans
- Evolution history (migrations) for understanding
- Best of both worlds

---

## Relationship to Git

**Git vs Migrations**:
- **Git**: Tracks file changes (code + specs)
- **Migrations**: Tracks semantic changes (feature evolution)

**Git shows**: "Line 42 changed from X to Y"
**Migrations show**: "Why we added notifications and how they work"

**They complement each other!**

---

## FAQ

### Q: Do I have to use migrations?
**A**: No! This is optional. Use when projects grow large and context windows become a problem.

### Q: Can I keep FEATURES.md manual?
**A**: Yes! Migrations are a complementary history, not a replacement. You can maintain FEATURES.md manually and migrations separately.

### Q: What if two agents create the same migration number?
**A**: Use timestamps or UUIDs. The migration tool handles this automatically.

### Q: Do migrations replace ADRs?
**A**: No. ADRs document architectural decisions. Migrations track spec evolution. They're complementary.

### Q: Can I skip a migration?
**A**: Yes, but document why in the migration file. Migrations aren't strictly sequential like database migrations.

### Q: How do I migrate an existing project?
**A**: Create migration 001 with current state, then add new changes as subsequent migrations.

---

## Implementation Status

- [x] Documentation (this file)
- [ ] Migration creation tool (`migration.sh create`)
- [ ] Migration listing tool (`migration.sh list`)
- [ ] Migration search tool (`migration.sh search`)
- [ ] Migration template
- [ ] Agent guidelines integration
- [ ] Optional: Snapshot generation (`migration.sh apply`)

---

## See Also

- **Continuous Quality Validation**: `.agentic/workflows/continuous_quality_validation.md`
- **Spec Schema**: `.agentic/spec/SPEC_SCHEMA.md`
- **Agent Operating Guidelines**: `.agentic/agents/shared/agent_operating_guidelines.md`

---

## Credits

**Migration concept**: Arto Jalkanen  
**Insight**: "Context window. Migrations are by default smaller, atomic operations where AI doesn't get tangled up as easily."

**Hybrid approach**: Tomas Günther & Arto Jalkanen  
- Maintaining both current-state specs (FEATURES.md) and migration history as complementary truths
- "Why not both?" - combining the benefits of snapshots (human-readable) and event logs (AI-efficient)

**Implementation**: Agentic AI Framework v0.4.0+

