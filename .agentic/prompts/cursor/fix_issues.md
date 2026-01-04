# Fix Issues Prompt

I have linter errors, test failures, or other issues that need fixing.

Please help me resolve them:

1. **Identify issues:**
   - Run linter/type checker if not already done
   - Run tests to see failures
   - Review error messages carefully

2. **Prioritize:**
   - Fix compilation/syntax errors first
   - Then fix failing tests
   - Then address linter warnings
   - Finally, consider style/formatting

3. **Fix systematically:**
   - Fix one issue at a time
   - Run checks after each fix to verify
   - Don't introduce new issues while fixing old ones
   - Keep changes minimal and focused

4. **Understand root causes:**
   - Don't just silence warnings
   - Fix the underlying problem
   - If unsure, research the error message
   - Add to `HUMAN_NEEDED.md` if you need guidance

5. **Test thoroughly:**
   - After fixing, run full test suite
   - Verify no regressions introduced
   - Check edge cases affected by changes

6. **Update documentation:**
   - If fixes changed behavior, update docs
   - Add JOURNAL.md entry if fixes were significant
   - Update comments if code logic changed

7. **Commit:**
   - Descriptive commit message explaining fixes
   - Group related fixes together
   - Separate refactoring from bug fixes

---

**Common Issues:**

**TypeScript/JavaScript:**
- Type errors → Add proper types, avoid `any`
- ESLint warnings → Follow project conventions
- Import errors → Check module resolution

**Python:**
- Type errors → Add type hints, use mypy
- Pylint warnings → Follow PEP 8
- Import errors → Check PYTHONPATH, package structure

**Rust:**
- Compiler errors → Read error messages carefully (Rust has great error messages!)
- Clippy warnings → Follow Rust idioms
- Borrow checker → Rethink ownership model

**General:**
- Test failures → Read test output, check assumptions
- Performance issues → Profile before optimizing
- Security warnings → Take seriously, never ignore

---

**If stuck:**
- Re-read error message slowly
- Search for error message + language/framework
- Check official documentation
- Add to `HUMAN_NEEDED.md` with full context
- Consider asking in project chat or issue tracker

