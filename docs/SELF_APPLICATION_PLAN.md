# Framework Self-Application Plan

**Problem**: "The cobbler's children have no shoes" - We built a quality framework but don't use it on ourselves!

**Goal**: Dogfood the Agentic AF framework to develop the framework itself.

---

## Current State (❌ Gaps)

**What we DON'T have**:
- ❌ No `spec/` folder for framework features
- ❌ No tests for Python tools (query_features.py, validate_specs.py, etc.)
- ❌ No quality validation running on framework code
- ❌ No FEATURES.md tracking framework development
- ❌ No STATUS.md for framework roadmap
- ❌ No retrospectives on framework development
- ❌ No acceptance criteria for framework features
- ❌ Not using our own Core+PM mode!

**What we DO have** (partial):
- ✅ `FRAMEWORK_DEVELOPMENT.md` (guidelines for working ON framework)
- ✅ Example projects (demonstrate features)
- ✅ `PRINCIPLES.md` (values and anti-patterns)
- ✅ `CHANGELOG.md` (release history)
- ✅ Git workflow (commits, tags, releases)

---

## Proposed Solution

### Option 1: Full Core+PM Mode (Dogfooding)

**Initialize framework repo WITH the framework**:

```bash
# 1. Initialize framework in Core+PM mode
cd /path/to/agentic-framework
bash .agentic/init/scaffold.sh --profile core+product

# 2. Create specs for framework features
# spec/FEATURES.md with:
# - F-0001: Query features tool
# - F-0002: Bulk update tool
# - F-0003: Hierarchical organization
# - F-0004: Feature statistics dashboard
# ... etc.

# 3. Add tests for each tool
# tests/test_query_features.py
# tests/test_bulk_update.py
# tests/test_validate_specs.py
# etc.

# 4. Add quality validation
# quality_checks.sh that runs:
# - pytest tests/
# - flake8 or ruff for linting
# - mypy for type checking
# - Pre-commit hook validates specs

# 5. Use STATUS.md for roadmap
# Track what's in progress, what's next
```

**Benefits**:
- ✅ Full dogfooding - we use our own tools
- ✅ Clear roadmap of framework features
- ✅ Acceptance criteria for new features
- ✅ Tests ensure tools actually work
- ✅ Quality validation prevents regressions
- ✅ Retrospectives improve framework development process

**Drawbacks**:
- More overhead (but that's the point - test if our framework has good UX!)
- Need to maintain specs for framework itself
- Some meta-confusion (using framework to build framework)

---

### Option 2: Hybrid Approach (Practical)

**Use Core+PM for features, but lightweight for infrastructure**:

1. **Add `spec/FEATURES.md` for major features only**
   - F-0001: Phase 1 Scalability (v0.3.0) - tags, query, validation
   - F-0002: Phase 2 Scalability (v0.3.1) - hierarchical, bulk ops
   - F-0003: Phase 3 Scalability (v0.3.1) - stats dashboard
   - Track: status, acceptance criteria, tests

2. **Add tests for Python tools**
   ```
   tests/
     test_query_features.py
     test_bulk_update.py
     test_validate_specs.py
     test_feature_graph.py
     test_feature_stats.py
     test_organize_features.py
     fixtures/
       sample_features.md
       sample_hierarchical/
   ```

3. **Add quality validation**
   ```bash
   # tests/run_tests.sh
   pytest tests/ --cov=.agentic/tools
   flake8 .agentic/tools/*.py
   mypy .agentic/tools/*.py --strict
   ```

4. **Add pre-commit hook**
   - Run tests before commits
   - Lint Python code
   - Validate framework consistency

5. **Keep lightweight docs** (what we have)
   - FRAMEWORK_DEVELOPMENT.md (guidelines)
   - PRINCIPLES.md (values)
   - CHANGELOG.md (history)
   - No heavy STATUS.md or full PM overhead

**Benefits**:
- ✅ Tests ensure quality
- ✅ Track major features with specs
- ✅ Quality validation prevents bugs
- ✅ Less overhead than full Core+PM
- ✅ Still dogfooding core quality principles

**Drawbacks**:
- Not full dogfooding (missing some PM features)
- Still need discipline to maintain tests

---

### Option 3: Minimal Quality Focus

**Just add tests, no specs**:

1. Add comprehensive test suite for tools
2. Add quality validation (pytest, linting, type checking)
3. Run on every commit (pre-commit hook + CI)
4. Keep existing docs (FRAMEWORK_DEVELOPMENT.md, PRINCIPLES.md)

**Benefits**:
- ✅ Minimal overhead
- ✅ Quality ensured through tests
- ✅ Fast to implement

**Drawbacks**:
- ❌ Not dogfooding our own framework
- ❌ No clear roadmap of framework features
- ❌ Misses the point of "do we eat our own dog food?"

---

## Recommendation

**Start with Option 2 (Hybrid)**:

1. **Phase 1 (Immediate)**: Add tests for tools
   - Write pytest tests for all Python tools
   - Add fixtures with sample FEATURES.md
   - Ensure 80%+ coverage

2. **Phase 2 (This week)**: Add quality validation
   - Create `tests/run_tests.sh`
   - Add pre-commit hook for tests + linting
   - Run on CI (GitHub Actions)

3. **Phase 3 (Next milestone)**: Add lightweight specs
   - Create `spec/FEATURES.md` for major framework features
   - Track acceptance criteria
   - Link to tests

4. **Phase 4 (Ongoing)**: Evaluate and iterate
   - After 1-2 months, assess if we need full Core+PM
   - Retrospective on framework development process
   - Adjust based on what we learn

---

## Success Criteria

**We'll know we're successful when**:

✅ All Python tools have tests (pytest)
✅ Tests run on every commit (pre-commit hook)
✅ CI validates quality (GitHub Actions)
✅ Major framework features tracked in spec/FEATURES.md
✅ Quality validation catches regressions
✅ We can confidently say "we use our own framework"

---

## Meta-Benefits

Using our framework on itself will:
- ✅ Surface UX issues we miss as developers
- ✅ Validate that our tools actually work at scale
- ✅ Demonstrate best practices in examples
- ✅ Build confidence in framework quality
- ✅ Catch bugs before users do
- ✅ Improve documentation (we'll find gaps)

**The cobbler's children WILL have shoes!** 👞

---

## Next Steps

1. **Decide**: Which option? (Recommend Option 2)
2. **Implement**: Start with tests for Python tools
3. **Validate**: Run quality checks on every commit
4. **Track**: Add spec/FEATURES.md for major features
5. **Iterate**: Retrospective in 1-2 months

**Question**: Which approach do you prefer?

