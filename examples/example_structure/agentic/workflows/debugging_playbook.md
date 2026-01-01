# Debugging playbook

## First principles
- Reproduce > speculate.
- Make the bug small: smallest failing input, smallest failing test.
- Observe the system: logs/metrics/traces or temporary debug output.

## Procedure
1. **Make a reproduction**
   - Prefer a failing test.
   - If not possible, write a minimal script or documented steps.
2. **Localize**
   - Identify the boundary where behavior diverges from expectation.
3. **Hypothesize**
   - State assumptions explicitly.
4. **Experiment**
   - Change one variable at a time.
5. **Fix**
   - Fix the root cause, not the symptom.
6. **Prevent regression**
   - Add/adjust tests.
7. **Update truth**
   - Update `STATUS.md` and any relevant spec notes.


