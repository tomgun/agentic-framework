# Mark Feature Complete Prompt (Core+PM Mode)

Feature **F-[XXXX]** is ready to be marked complete.

Please verify and update:

1. **Code Quality:**
   - All tests pass (unit + integration + acceptance)
   - Code follows `.agentic/workflows/programming_standards.md`
   - No linter errors or warnings
   - Code is documented (comments where needed)

2. **Test Coverage:**
   - All acceptance criteria have corresponding tests
   - Edge cases covered
   - Error handling tested

3. **Run quality checks:**
   ```bash
   bash quality_checks.sh --pre-commit
   ```
   Fix any issues found.

4. **Update `spec/FEATURES.md`:**
   - Status: `shipped`
   - Implementation → State: `complete`
   - Implementation → Code: List all relevant files
   - Tests → Unit: `complete`
   - Tests → Integration: `complete` (if applicable)
   - Tests → Acceptance: `complete`
   - Note: Leave `Verification → Accepted: no` until human validates

5. **Update documentation:**
   - `JOURNAL.md`: Log completion and any final notes
   - `STATUS.md`: Update current focus/next steps
   - User-facing docs (if needed): Update README, guides, etc.

6. **Final verification:**
   - Read the acceptance criteria file `spec/acceptance/F-[XXXX].md`
   - Confirm each criterion is met
   - If anything is uncertain, add to `HUMAN_NEEDED.md`

7. **Commit:**
   - Commit all changes with descriptive message
   - Format: `feat(F-[XXXX]): [brief description]`
   - Include all doc updates in same commit

8. **Summary:**
   - Provide brief summary of what was implemented
   - Note any deviations from original spec
   - Suggest next feature or task

---

**Checklist:**
- ✓ All acceptance criteria met
- ✓ All tests pass
- ✓ Quality checks pass
- ✓ Specs updated (status: shipped, state: complete)
- ✓ Documentation updated
- ✓ Git committed

