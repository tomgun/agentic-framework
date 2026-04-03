# Capabilities

<!-- spec-format: capabilities-v1.0 -->

What this product can do — built, in progress, and planned.

**Status values**: `built` | `in_progress` | `planned`

**Entry format** (same for all profiles):

```markdown
## Search
**Status**: built
Full-text product search with filters across name, category, price range.
Decisions: Used Elasticsearch over Postgres FTS for scale.
```

In formal/autonomous_formal profiles, capabilities may also have contracts in `spec/contracts/` with acceptance criteria and verification commands. The catalog entry stays the same — contracts are a separate layer.

Register capabilities: `bash .agentic/lib/tools/feature.sh cap add "Name" "Description" --decisions "Why"`

---

<!-- Add capability entries below, most recent first -->
