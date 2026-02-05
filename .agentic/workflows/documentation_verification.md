# Documentation Verification Protocol

**Purpose**: Ensure agents use current, version-correct documentation when generating code to avoid implementing deprecated patterns, removed APIs, or outdated best practices.

## The Problem

AI models are trained on historical documentation, leading to:
- Using deprecated or removed APIs
- Following obsolete patterns
- Missing new features
- Security vulnerabilities from outdated practices
- Breaking changes not accounted for

## Solution: Multi-Layered Verification

### Layer 1: Version Declaration (MANDATORY)

**In STACK.md, declare exact versions:**

```markdown
## Languages & runtimes
- Language(s): TypeScript 5.3
- Runtime(s): Node.js 22.11 LTS

## Frameworks & libraries
- App framework: Next.js 15.1.0
- UI framework: React 19.0.0
- Database: PostgreSQL 16.2
- ORM: Prisma 6.0.0
- Testing: Vitest 2.1.5

## Documentation sources (IMPORTANT)
<!-- Agents MUST verify they're using docs for these versions -->
- Next.js docs: https://nextjs.org/docs (v15.1)
- React docs: https://react.dev (v19)
- Prisma docs: https://www.prisma.io/docs (v6)
```

### Layer 2: Documentation Verification Tools (RECOMMENDED)

**Option A: Context7 MCP Server (recommended)**

Context7 provides real-time, version-specific documentation as an MCP (Model Context Protocol) server. When configured, agents can call `resolve-library-id` and `get-library-docs` to get accurate, version-locked API docs on demand.

**Setup for Cursor** (`.cursor/mcp.json`):
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

**Setup for Claude Desktop** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

**Enable in STACK.md:**
```markdown
## Documentation verification (recommended)
- doc_verification: context7-mcp
- context7_mcp: enabled
- strict_version_matching: yes
```

**How agents use it:**
1. Agent needs to use a library API → calls `resolve-library-id` with library name
2. Gets back a library ID → calls `get-library-docs` with ID and topic
3. Receives version-specific, accurate documentation
4. Uses verified API signatures in code

**Option B: Web Search Verification**

Most AI coding tools (Cursor, Claude, Copilot) have built-in web search. Agents should:
1. Search for `[library] [version] [API name] documentation`
2. Verify the docs page shows the correct version
3. Use only APIs confirmed in current docs

**Option C: Source Code Inspection (always available)**

Read the actual source in `node_modules/`, `site-packages/`, or equivalent:
```bash
# Check actual API signatures
grep -r "export function" node_modules/@prisma/client/
cat node_modules/next/dist/types.d.ts
```

**Option D: Manual Version Checks (minimum)**

If no verification tools are available, agents MUST:
1. Before using any API, verify version in STACK.md
2. Check official docs for that specific version
3. Look for "deprecated" or "removed in vX" warnings
4. Verify examples match the declared version

### Layer 3: Agent Verification Protocol (MANDATORY)

**Before writing code using a library/framework:**

1. **Read STACK.md versions** — know what versions this project uses
2. **Verify documentation source** — use Context7 MCP, web search, or official docs
3. **Check for breaking changes** — read changelog/migration guide for current version
4. **Verify API signature before using** — function name, parameters, return type
5. **If unsure, escalate** — add to HUMAN_NEEDED.md

### Layer 4: Automated Version Checks (TOOLING)

**Tool: `version_check.sh`**

Checks that dependencies in package files match STACK.md declarations.

```bash
bash .agentic/tools/version_check.sh
```

**Output:**
```
=== Version Check ===

✅ Next.js: 15.1.0 (matches STACK.md)
❌ React: 18.3.0 (STACK.md declares 19.0.0) - UPDATE NEEDED
✅ Prisma: 6.0.0 (matches STACK.md)
⚠️  TypeScript: 5.3.2 (STACK.md declares 5.3) - minor mismatch OK

Recommendations:
- Update React to 19.0.0 or update STACK.md to reflect 18.3.0
```

---

## Sources of Truth (Priority Order)

| Priority | Source | When to Use |
|----------|--------|-------------|
| 1 | **Context7 MCP** (if configured) | Version-locked, most reliable |
| 2 | **Official docs** for EXACT version | Always available |
| 3 | **Source code** in node_modules/ etc. | Ground truth for signatures |
| 4 | **Web search** for current docs | Good for recent changes |
| 5 | **Human confirmation** (HUMAN_NEEDED.md) | When uncertain |
| ❌ | **Training data / memory** | NEVER rely on this alone |

---

## Common Pitfalls & Prevention

### Pitfall 1: "I remember this API..."
**Problem**: Model trained on old docs, "remembers" removed API.
**Prevention**: Always verify in current docs or via Context7 before using any API.

### Pitfall 2: Copy-pasted outdated examples
**Problem**: Examples from tutorials/blogs use old versions.
**Prevention**: Only use examples from official docs for your version. Check publish date.

### Pitfall 3: Framework defaults changed
**Problem**: Default behavior changed between versions.
**Prevention**: Read migration guide for major versions. Don't rely on defaults without verifying.

### Pitfall 4: Deprecated but still works
**Problem**: Using deprecated API that hasn't been removed yet.
**Prevention**: Check docs for deprecation warnings. Treat deprecations as errors.

---

## Configuration in STACK.md

```markdown
## Documentation verification (recommended)
<!-- Ensure agents use current, version-correct documentation -->
- doc_verification: context7-mcp  # context7-mcp | web-search | manual | none
- context7_mcp: enabled           # Requires MCP server config in IDE
- strict_version_matching: yes    # Fail if docs don't match versions

## Documentation sources (for manual verification)
<!-- Agents verify these sources match STACK versions -->
- Next.js: https://nextjs.org/docs (version selector: v15.1)
- React: https://react.dev (v19)
- Prisma: https://www.prisma.io/docs (v6)

## Version update policy
- major_updates: human_approval_required
- minor_updates: quarterly_review
- patch_updates: auto_apply_security
- deprecation_warnings: treat_as_errors
```

---

## See Also

- Anti-hallucination rules: `.agentic/agents/shared/guidelines/anti-hallucination.md`
- Agent guidelines: `.agentic/agents/shared/agent_operating_guidelines.md`
- Research mode: `.agentic/workflows/research_mode.md`
- Definition of Done: `.agentic/workflows/definition_of_done.md`
