# Anti-Hallucination Rules (NON-NEGOTIABLE)

**Core Problem**: LLM hallucination undermines ALL quality principles. If the foundation is fabricated, tests and validation are meaningless.

---

## Rule 1: NEVER Make Things Up

**If you don't know something with certainty, you MUST**:
1. **State uncertainty**: "I'm not certain about X"
2. **Look it up**: Read official docs, search web
3. **Ask the human**: Add to HUMAN_NEEDED.md if you can't verify
4. **NEVER guess or fabricate**: No "I think...", no plausible-sounding inventions

**Forbidden behavior**:
- "React 18 has a useServerComponent hook" (hallucinated - doesn't exist)
- "The API endpoint is probably /api/users/update" (don't guess)
- "This library likely uses JWT for auth" (verify, don't assume)
- "The function signature is probably func(x, y, z)" (look it up)

**Correct behavior**:
- "I need to check the React 18 documentation for the correct hook"
- "Let me read the API documentation to confirm the endpoint"
- "I'll search for this library's authentication method"
- "Adding to HUMAN_NEEDED.md: Need to clarify the function signature"

---

## Rule 2: Verify Technical Claims

**BEFORE writing code using a library/API/framework feature, VERIFY**:

1. **Function/method signatures** (arguments, return types)
2. **API endpoints and HTTP methods**
3. **Configuration options and valid values**
4. **Import paths and module names**
5. **Breaking changes between versions**
6. **Deprecated features**

**Sources of truth** (in order of preference):
1. **Context7** (if enabled) - version-locked, reliable
2. **Official documentation** for the EXACT version
3. **Source code** in node_modules/ or site-packages/
4. **Human confirmation** (HUMAN_NEEDED.md)
5. **NEVER**: Your training data, guesses, assumptions

---

## Rule 3: Document Blockers Immediately

**CRITICAL**: If you identify something requiring human action, ADD IT TO HUMAN_NEEDED.md IMMEDIATELY.

**Always add to HUMAN_NEEDED.md when**:
- Manual dependency installation needed
- Credentials required (API keys, passwords)
- External account creation needed
- Design decisions pending
- Access permissions required
- Hardware/device needed
- User approval needed

**BAD**:
```
Agent: "You'll need to install the GUT plugin manually."
[Session ends, blocker forgotten]
```

**GOOD**:
```
Agent: "You'll need to install the GUT plugin. Adding to HUMAN_NEEDED.md now."
bash .agentic/tools/blocker.sh add "Install GUT plugin" "dependency" "Manual install via Asset Library"
```

**Rule**: Mention in chat AND add to HUMAN_NEEDED.md. Session may end abruptly.

---

## Rule 4: Document Uncertainty

When uncertain, add to HUMAN_NEEDED.md:

```bash
bash .agentic/tools/blocker.sh add \
  "Verify authentication method" \
  "technical" \
  "I found OAuth and JWT mentioned. Which is current? Files: auth.ts, config.ts"
```

**Impact levels**:
- **Critical**: Blocks implementation (missing API key)
- **High**: Affects architecture (auth method unclear)
- **Medium**: Affects quality (unclear requirements)
- **Low**: Nice to know (coding style preference)

---

## Summary

| Situation | Action |
|-----------|--------|
| Uncertain about API | Look up official docs for exact version |
| Can't verify something | Add to HUMAN_NEEDED.md |
| Making assumption | STOP. Verify or document uncertainty |
| Found blocker | Add to HUMAN_NEEDED.md IMMEDIATELY |
| Session ending | Ensure all blockers documented |

**The cost of hallucination > The cost of asking.**
