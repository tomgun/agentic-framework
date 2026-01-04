# Project Retrospective Prompt

I want to run a retrospective on this project.

Please conduct a comprehensive review:

1. **Project health check:**
   - Review `STATUS.md` or `PRODUCT.md` - is it accurate and up-to-date?
   - Check `JOURNAL.md` - are entries recent and meaningful?
   - For Core+PM: Review `spec/FEATURES.md` - do statuses match reality?
   - Check `HUMAN_NEEDED.md` - any stale items?

2. **Code quality assessment:**
   - Run full quality checks: `bash quality_checks.sh --full`
   - Review test coverage - any gaps?
   - Check for code duplication or complexity hotspots
   - Review recent commits - good quality and descriptive messages?

3. **Technical debt inventory:**
   - Search for TODO/FIXME comments in code
   - Identify areas that need refactoring
   - Note dependencies that need updating
   - Security vulnerabilities or warnings?

4. **Documentation review:**
   - Is README current and accurate?
   - Are setup instructions still valid?
   - Is architecture documentation up-to-date?
   - Are ADRs (Architecture Decision Records) capturing key decisions?

5. **Process improvements:**
   - What's working well?
   - What's causing friction?
   - Are we following TDD consistently?
   - Is documentation staying current?
   - Are quality checks catching issues?

6. **Spec consistency (Core+PM mode):**
   - Run: `python3 .agentic/tools/validate_specs.py`
   - Run: `python3 .agentic/tools/consistency.py`
   - Review any inconsistencies found
   - Fix or document exceptions

7. **Create retrospective document:**
   - Save to: `docs/retrospectives/YYYY-MM-DD.md`
   - Include:
     - Summary of current state
     - What's going well
     - What needs improvement
     - Specific action items
     - Technical debt to address
     - Process changes to try

8. **Generate action items:**
   - List concrete, actionable improvements
   - Prioritize (critical, important, nice-to-have)
   - Assign to humans or create tasks for agents
   - Add high-priority items to `HUMAN_NEEDED.md` if human decision needed

9. **Update project docs:**
   - Update `STATUS.md`/`PRODUCT.md` with insights
   - Add JOURNAL.md entry summarizing retro
   - Update `.agentic/STACK.md` if process changes needed

---

**Retrospective Schedule:**
- Small projects: Monthly
- Active development: Every 2 weeks
- Critical projects: Weekly
- Before major releases: Always

**Focus Areas:**
- ✓ Code quality and maintainability
- ✓ Test coverage and reliability
- ✓ Documentation accuracy
- ✓ Development velocity
- ✓ Technical debt management
- ✓ Team/agent collaboration effectiveness

---

**Output Format:**
Create a clear, actionable retrospective document with:
1. Executive summary (2-3 sentences)
2. Health metrics (tests, coverage, quality)
3. Wins (what went well)
4. Challenges (what didn't)
5. Action items (specific, prioritized)
6. Next retrospective date

