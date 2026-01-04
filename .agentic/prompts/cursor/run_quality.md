# Run Quality Checks Prompt

I want to run quality checks before committing.

Please:

1. **Check for quality_checks.sh:**
   - If `quality_checks.sh` exists in project root, run it:
     ```bash
     bash quality_checks.sh --pre-commit
     ```
   - This runs fast, pre-commit checks (linting, unit tests, basic validation)

2. **If no quality_checks.sh, run manual checks:**
   - **Linter:** Run project linter (eslint, pylint, cargo clippy, etc.)
   - **Formatter:** Check code formatting (prettier, black, rustfmt, etc.)
   - **Tests:** Run unit tests (fast ones only)
   - **Type checking:** If applicable (TypeScript, mypy, etc.)

3. **Review results:**
   - Fix any errors or warnings
   - If something is unclear, ask me or add to `HUMAN_NEEDED.md`

4. **Optional full checks:**
   - To run comprehensive checks (slow): `bash quality_checks.sh --full`
   - Includes: integration tests, performance checks, security scans
   - Usually run before merging to main or before releases

---

**Quality Profile:**
- Quality checks are technology-specific
- Configured during framework initialization
- See `.agentic/quality_profiles/` for available profiles
- Can be customized in project root `quality_checks.sh`

**Troubleshooting:**
- If checks fail, read error output carefully
- Fix issues one at a time
- If stuck, add to `HUMAN_NEEDED.md` with context
- Some warnings can be ignored (document why in code)

**Before every commit:**
- ✓ Quality checks pass
- ✓ Tests pass
- ✓ No unintended changes in git diff
- ✓ Documentation updated

