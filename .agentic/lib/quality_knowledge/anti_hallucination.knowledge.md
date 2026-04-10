# Anti-Hallucination Rules

Verification rules to prevent fabricated APIs, guessed paths, and unverified technical claims. These are non-negotiable for all agents.

## Rule 1: Never Fabricate

If you don't know something with certainty:
1. **State uncertainty**: "I'm not certain about X"
2. **Look it up**: Read official docs, search the web, read the source code
3. **Ask the human**: Add to HUMAN_NEEDED.md if you can't verify
4. **Never guess**: No "I think...", no plausible-sounding inventions

### Forbidden
- "React 18 has a useServerComponent hook" (hallucinated — doesn't exist)
- "The API endpoint is probably /api/users/update" (don't guess endpoints)
- "This library likely uses JWT for auth" (verify, don't assume)
- "The function signature is probably func(x, y, z)" (read the source)

### Correct
- "I need to check the React 18 docs for the correct hook"
- "Let me read the API docs to confirm the endpoint"
- "Adding to HUMAN_NEEDED.md: Need to clarify the auth method"

**The cost of hallucination > the cost of asking.**

## Rule 2: Verify Before Using

Before writing code that uses a library, API, or framework feature, verify:

| What | How to Verify |
|------|---------------|
| Function signatures | Read source code or official docs for your exact version |
| API endpoints & methods | Check API docs or OpenAPI spec |
| Config options & values | Read framework docs for your version |
| Import paths & modules | Check `node_modules/`, `site-packages/`, or package docs |
| Breaking changes | Check CHANGELOG or migration guides between versions |
| Deprecated features | Check docs — deprecated APIs may be removed |

### Sources of Truth (in order)
1. **Source code** in the project's dependencies (`node_modules/`, `site-packages/`)
2. **Official documentation** for the EXACT version in use
3. **Web search** for recent, authoritative sources
4. **Human confirmation** via HUMAN_NEEDED.md
5. **NEVER**: Training data alone, guesses, assumptions

## Rule 3: Check Before Creating

Before creating ANY new file, test, or component, search for existing equivalents.

| Creating | Search First |
|----------|--------------|
| New file | `glob` for similar names in the target directory |
| New test | `grep` for similar test names, check existing test files |
| New component | Search codebase for similar names/functionality |
| New utility | Check `utils/`, `helpers/`, `common/`, `lib/` for existing functions |
| New document | Check `docs/` and existing `.md` files for the topic |

A 30-second search prevents hours of duplicate work and maintenance burden.

## Rule 4: Document Blockers Immediately

If you identify something requiring human action, add it to HUMAN_NEEDED.md NOW — not later.

```bash
bash .agentic/lib/tools/blocker.sh add "Title" "type" "Details"
```

### Always Document When
- Manual dependency installation needed (tools, plugins, SDKs)
- Credentials required (API keys, passwords, certificates)
- External account creation needed (cloud services, third-party APIs)
- Design decisions need human input
- Access permissions required
- Hardware/device needed for testing

### Why Immediately
Sessions can end abruptly. If you mention a blocker in chat but don't persist it, the information is lost. Mention in chat AND add to HUMAN_NEEDED.md.

## Rule 5: Document Uncertainty

When you're uncertain about something that affects implementation:

```bash
bash .agentic/lib/tools/blocker.sh add \
  "Verify authentication method" \
  "technical" \
  "Found OAuth and JWT mentioned in auth.ts and config.ts. Which is current?"
```

Don't proceed on assumptions for critical decisions (auth, data models, external integrations). Proceeding on wrong assumptions wastes more time than pausing to verify.

## Summary

| Situation | Action |
|-----------|--------|
| Uncertain about an API/library feature | Look up docs for exact version |
| Can't verify a technical claim | Ask or add to HUMAN_NEEDED.md |
| About to make an assumption | STOP — verify or document uncertainty |
| Found a blocker during work | Add to HUMAN_NEEDED.md immediately |
| Creating a new file/component | Search for existing equivalents first |
