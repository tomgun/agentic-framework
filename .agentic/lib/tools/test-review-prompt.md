---
summary: "LLM prompt template for reviewing whether tests actually validate acceptance criteria"
tokens: ~400
phase: verification
---

# Test-AC Intent Match Review

You are reviewing whether a test actually validates what an acceptance criterion promises.

## Input

**Acceptance Criterion**:
{ac_text}

**Test Source Code**:
```
{test_code}
```

## Questions to Answer

1. **Exercise**: Does this test exercise the specific behavior described in the AC? (not just a related behavior)
2. **Assertions**: Are assertions checking the right thing? (not just status codes or existence checks)
3. **False pass**: Could this test pass with a broken implementation? (the key question — if yes, the test is weak)
4. **Edge cases**: Does the test cover edge cases mentioned or implied by the AC?
5. **Substance**: Is this a real test or a "looks like a test" placeholder? (empty body, trivial assertion, no-op)

## Output Format

For each AC-test pair, respond with:

```
verdict: pass | concern | fail
confidence: high | medium | low
explanation: [1-2 sentences explaining the verdict]
suggestion: [if concern/fail: what the test should assert instead]
```

**Verdicts**:
- `pass`: Test meaningfully validates the AC
- `concern`: Test partially validates but has gaps (e.g., missing edge cases, weak assertions)
- `fail`: Test does not validate the AC (e.g., asserts wrong thing, could pass with broken implementation, placeholder)

Be specific. "Test looks fine" is not acceptable. Cite the specific assertion that does or doesn't match the AC.
