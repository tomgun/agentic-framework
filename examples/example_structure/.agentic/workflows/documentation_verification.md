# Documentation Verification Protocol

**Purpose**: Ensure agents use current, version-correct documentation when generating code to avoid implementing deprecated patterns, removed APIs, or outdated best practices.

## The Problem

AI models can be trained on outdated documentation, leading to:
- Using deprecated APIs
- Following obsolete patterns
- Missing new features
- Security vulnerabilities
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

**Option A: Context7 (AI-powered documentation)**

Context7 provides real-time, version-specific documentation for AI assistants.

**Enable in STACK.md:**
```markdown
## Documentation verification (recommended)
- doc_verification: context7
- context7_enabled: yes
- context7_config: .context7.yml  # Project-specific config
```

**Setup `.context7.yml` in project root:**
```yaml
# Context7 configuration
# See: https://context7.com/docs

dependencies:
  - name: nextjs
    version: "15.1.0"
    docs_url: https://nextjs.org/docs
  
  - name: react
    version: "19.0.0"
    docs_url: https://react.dev
  
  - name: prisma
    version: "6.0.0"
    docs_url: https://www.prisma.io/docs

verification:
  strict_mode: true  # Fail if version mismatch
  warn_on_deprecated: true
  check_breaking_changes: true
```

**Option B: Manual Version Checks (minimum)**

If not using Context7, agents MUST:

1. **Before using any API, verify version in STACK.md**
2. **Check official docs for that specific version**
3. **Look for "deprecated" or "removed in vX" warnings**
4. **Verify examples match the declared version**

### Layer 3: Agent Verification Protocol (MANDATORY)

**Before writing code using a library/framework:**

```markdown
## Pre-Implementation Checklist

1. **Read STACK.md versions**
   - Framework: [Name] v[X.Y.Z]
   - Last updated: [Check git log on STACK.md]

2. **Verify documentation source**
   - If Context7 enabled: Use Context7 docs
   - If not: Go to official docs and verify version selector is set correctly
   - URL: [official docs URL]
   - Version shown: [verify matches STACK.md]

3. **Check for breaking changes**
   - Read changelog/migration guide for current version
   - Check "What's new in v[X]" or release notes
   - Look for deprecation warnings

4. **Verify API signature before using**
   - Function/method name: [name]
   - Parameters: [verify against current docs]
   - Return type: [verify]
   - Deprecated: [yes/no]
   - Available since: [version]

5. **Document version in code comments**
   ```typescript
   // Using Next.js 15.1 App Router API
   // Ref: https://nextjs.org/docs/app/api-reference/functions/...
   export default async function Page() {
     // ...
   }
   ```

6. **If unsure, escalate to human**
   - Add to HUMAN_NEEDED.md: "Verify [API] is correct for [framework] v[X]"
```

### Layer 4: Automated Version Checks (TOOLING)

**New tool: `version_check.sh`**

Checks that dependencies in package files match STACK.md declarations.

```bash
#!/usr/bin/env bash
# Compares versions in package.json/requirements.txt/go.mod with STACK.md

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
- Review breaking changes: https://react.dev/blog/2024/12/05/react-19
```

## Context7 Integration (Recommended)

### What is Context7?

Context7 is a service that provides AI assistants with:
- **Version-specific documentation** (no hallucinated old APIs)
- **Breaking change warnings** (alerts when using deprecated APIs)
- **Live examples** (code that actually works with current versions)
- **Changelog integration** (recent changes highlighted)

### How to Enable

1. **Sign up**: https://context7.com (free tier available)
2. **Install**: 
   ```bash
   npm install -D @context7/cli
   # or
   pip install context7
   ```
3. **Configure** `.context7.yml` (see above)
4. **Update STACK.md**:
   ```markdown
   ## Documentation verification
   - doc_verification: context7
   - context7_enabled: yes
   ```
5. **Agent automatically uses Context7** when generating code

### Benefits

✅ **Always current**: Docs updated when new versions release  
✅ **Version-aware**: Only shows APIs available in your version  
✅ **Breaking change warnings**: Prevents using removed APIs  
✅ **Context-specific**: Shows examples relevant to your stack  
✅ **Reduces hallucinations**: AI uses verified, current docs

## Agent Operating Guidelines Integration

### Updated: `.agentic/agents/shared/agent_operating_guidelines.md`

**New rule: Documentation Verification**

```markdown
## Before using any library/framework API

1. **Check STACK.md for declared version**
2. **Verify documentation source**:
   - If `context7_enabled: yes` in STACK.md → Use Context7 docs
   - Otherwise → Go to official docs, verify version selector matches STACK.md
3. **Check for deprecation warnings** in current docs
4. **Verify API signature** matches current version
5. **If documentation seems outdated or contradictory**:
   - STOP implementation
   - Add to HUMAN_NEEDED.md: "Documentation verification needed for [API]"
   - Suggest running Research Mode to investigate current best practices
6. **Add version comment** in code referencing docs

**NEVER assume an API exists without verifying in current docs.**
**NEVER use deprecated APIs without explicit human approval.**
```

## Common Pitfalls & How to Avoid

### Pitfall 1: "I remember this API..."

**Problem**: Model trained on old docs, "remembers" removed API.

**Prevention**:
- ✅ Always check current docs before using any API
- ✅ Use Context7 to get version-specific docs
- ✅ Search official docs for API name before implementing

### Pitfall 2: Copy-pasted outdated examples

**Problem**: Examples from tutorials/blogs use old versions.

**Prevention**:
- ✅ Only use examples from official docs for your version
- ✅ Verify import statements match current package structure
- ✅ Check publish date on tutorials (>6 months = suspicious)

### Pitfall 3: Framework defaults changed

**Problem**: Default behavior changed between versions.

**Prevention**:
- ✅ Read "What's new" / migration guide for major versions
- ✅ Check for "breaking changes" section in changelog
- ✅ Test assumptions (don't rely on defaults without verifying)

### Pitfall 4: Deprecated but still works

**Problem**: Using deprecated API that hasn't been removed yet.

**Prevention**:
- ✅ Check docs for deprecation warnings
- ✅ Use linters that detect deprecated usage
- ✅ Treat deprecations as errors (will break in next major version)

## Integration with Research Mode

When entering Research Mode to investigate a technology:

**Always include in research:**
1. **Current version**: What's the latest stable?
2. **Migration path**: How to upgrade from current to latest?
3. **Breaking changes**: What changed between versions?
4. **Deprecations**: What's deprecated in current version?
5. **Roadmap**: What's coming in next versions?

**Document in research report:**
```markdown
## Version Information

- Current version (in project): X.Y.Z
- Latest stable: A.B.C
- Latest LTS: A.B.C (support until YYYY-MM-DD)
- Versions behind: N major / M minor

## Breaking Changes Since Our Version

### X.Y → X+1.0
- Change 1: [impact on our code]
- Change 2: [impact]

### X+1.0 → A.B
- Change 3: [impact]

## Deprecations in Our Version

- API 1: Deprecated in X.Y, removed in X+1.0
  - Used in: [file paths]
  - Replacement: [new API]
  - Migration: [steps]
```

## Integration with Retrospective

During retrospectives, check:

```markdown
### Documentation Currency Check

**Questions:**
- Are all versions in STACK.md current? (Last updated: [date])
- Are we using deprecated APIs? (Run deprecation linter)
- Are docs sources still valid? (URLs work, version selectors accurate)
- Is Context7 (or alternative) configured correctly?

**Actions:**
- [ ] Update STACK.md with current versions
- [ ] Review deprecation warnings
- [ ] Update .context7.yml if versions changed
- [ ] Run version_check.sh and fix mismatches
```

## Configuration in STACK.md

```markdown
## Documentation verification (recommended)
<!-- Ensure agents use current, version-correct documentation -->
- doc_verification: context7  # context7 | manual | none
- context7_enabled: yes
- context7_config: .context7.yml
- strict_version_matching: yes  # Fail if docs don't match versions

## Documentation sources (for manual verification)
<!-- If not using Context7, agents must manually verify these -->
- Next.js: https://nextjs.org/docs (version selector: v15.1)
- React: https://react.dev (v19)
- Prisma: https://www.prisma.io/docs (v6)

## Version update policy
- major_updates: human_approval_required
- minor_updates: quarterly_review
- patch_updates: auto_apply_security
- deprecation_warnings: treat_as_errors
```

## Enforcement in Definition of Done

Add to `.agentic/workflows/definition_of_done.md`:

```markdown
## Documentation Verification (required)

- [ ] All APIs used match versions declared in STACK.md
- [ ] No deprecated APIs used (or explicitly approved in HUMAN_NEEDED.md)
- [ ] Version comments added to code referencing external docs
- [ ] If Context7 enabled, Context7 docs were used
- [ ] If manual verification, docs version was checked and matched
```

## Example: Correct Documentation Usage

### ❌ BAD (No Version Verification)

```typescript
// Agent generates code without checking
import { useRouter } from 'next/navigation'

export default function Page() {
  const router = useRouter()
  router.push('/dashboard')  // Might be wrong API for our version!
}
```

### ✅ GOOD (With Verification)

```typescript
// Next.js 15.1 App Router API
// Verified: https://nextjs.org/docs/app/api-reference/functions/use-router
// Date: 2026-01-15
import { useRouter } from 'next/navigation'

export default function Page() {
  // useRouter in App Router (Next.js 13+) returns:
  // - push(href: string, options?: NavigateOptions)
  // - refresh(), back(), forward(), prefetch()
  const router = useRouter()
  router.push('/dashboard')  // ✅ Verified current API
}
```

## Alternative Tools to Context7

If Context7 doesn't fit your needs:

### DevDocs.io
- Offline documentation
- Version-specific docs
- Free, open-source
- Configuration: `.devdocs.json`

### Dash / Zeal
- Offline documentation browser
- Version management
- Local caching
- IDE integration

### Custom Documentation Server
- Host your own versioned docs
- Full control
- Air-gapped environments
- Point agents to internal URLs

## Migration from No Verification

**Phase 1: Audit (Week 1)**
1. Run `version_check.sh` to identify mismatches
2. Review codebase for deprecated API usage
3. Document findings in retrospective report

**Phase 2: Configure (Week 1)**
1. Add exact versions to STACK.md
2. Set up Context7 or alternative
3. Update agent guidelines
4. Add to Definition of Done

**Phase 3: Enforce (Week 2+)**
1. Agents follow verification protocol
2. Code reviews check version comments
3. Linters detect deprecated usage
4. Regular version currency checks in retrospectives

## Benefits

✅ **Fewer bugs**: Using correct APIs for your versions  
✅ **No breaking surprises**: Aware of deprecations before they break  
✅ **Up-to-date code**: Following current best practices  
✅ **Easier upgrades**: Know what needs changing  
✅ **Better code review**: Version comments help reviewers  
✅ **Token-efficient**: Correct on first try, less debugging

## See Also

- Agent guidelines: `.agentic/agents/shared/agent_operating_guidelines.md`
- Research mode: `.agentic/workflows/research_mode.md`
- Retrospective workflow: `.agentic/workflows/retrospective.md`
- Definition of Done: `.agentic/workflows/definition_of_done.md`

