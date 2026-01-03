# Framework Development Guidelines

**🎯 Scope**: Additional guidelines for agents working **ON the Agentic AI Framework itself** (not projects using it).

**For projects using the framework**: See [`agents/shared/agent_operating_guidelines.md`](agents/shared/agent_operating_guidelines.md).

---

## Core Responsibilities

When working on the framework repository (`agentic-framework`), you have additional responsibilities beyond normal project development:

### 1. **Maintain Internal Consistency**

Every change must maintain consistency across:
- ✅ Templates in `.agentic/init/` and `.agentic/spec/`
- ✅ Example projects in `examples/`
- ✅ Documentation in `README.md`, `START_HERE.md`, `DEVELOPER_GUIDE.md`
- ✅ Agent guidelines in `.agentic/agents/`
- ✅ Tool scripts in `.agentic/tools/`

**Rule**: If you change a template, workflow, or guideline → update examples and docs to match.

---

### 2. **Example Projects Are First-Class Citizens**

Example projects demonstrate best practices and verify workflows actually work.

**When to update examples**:
- ✅ Adding new framework features
- ✅ Changing templates or guidelines
- ✅ Modifying workflow documents
- ✅ Updating quality standards

**How to update examples**:
1. List all example projects: `ls examples/`
2. For each example in relevant profile (Core or Core+PM):
   - Apply changes manually or regenerate
   - Verify scripts work: `doctor.py`, `verify.py`, etc.
   - Test quality checks if applicable
   - Update example READMEs if workflow changed
3. Commit examples with framework changes

**Example projects to maintain**:
- `examples/core_todo_cli/` - Core profile example
- `examples/core_pm_taskboard/` - Core+PM profile example
- Keep `examples/old/` as reference but don't update

---

### 3. **Documentation Single Source of Truth**

**The DRY Rule**: Information lives in ONE place, others reference it.

**Master documents** (single source of truth):
- **`DEVELOPER_GUIDE.md`**: All script explanations, comprehensive command table, automation guide
- **`PRINCIPLES.md`**: All framework principles and values
- **`STACK.template.md`**: Canonical structure for STACK.md
- **`FEATURES.template.md`**: Canonical structure for FEATURES.md

**Reference documents** (cross-reference masters):
- **`MANUAL_OPERATIONS.md`**: Quick patterns, references DEVELOPER_GUIDE for details
- **`START_HERE.md`**: Navigation, references comprehensive docs
- **`README.md`**: Overview, links to detailed guides

**When updating information**:
1. Find where it lives authoritatively (usually DEVELOPER_GUIDE or PRINCIPLES)
2. Update ONCE in that location
3. Verify cross-references are still accurate
4. Don't duplicate - add cross-reference if needed

**Anti-pattern**: ❌ Copying script explanation to 3 files instead of putting in DEVELOPER_GUIDE and referencing it.

---

### 4. **Test Framework Changes**

**Before committing changes to framework core**:

1. **Test in a scratch project**:
   ```bash
   mkdir /tmp/test-framework
   cd /tmp/test-framework
   git init
   bash /path/to/agentic-framework/install.sh .
   ```

2. **Verify initialization**:
   - Run through init_playbook.md
   - Test both Core and Core+PM profiles
   - Verify scaffold.sh creates correct files

3. **Test tools work**:
   ```bash
   python .agentic/tools/doctor.py
   python .agentic/tools/verify.py
   bash .agentic/tools/brief.sh
   ```

4. **Test workflows**:
   - Add a feature (Core+PM)
   - Implement with TDD
   - Run quality checks
   - Verify documentation updates

5. **Test upgrade path** (if changing templates/structure):
   ```bash
   cd /tmp/old-project  # Project on v0.2.3
   bash /path/to/new-framework/upgrade.sh
   # Verify upgrade worked
   ```

**Anti-pattern**: ❌ Changing templates without testing in real project. ❌ "It should work" without verification.

---

### 5. **Version Management**

**When bumping framework version**:

1. **Update `VERSION` file**:
   ```bash
   echo "0.2.5" > VERSION
   ```

2. **Update `CHANGELOG.md`**:
   - Add new version section at top
   - List all changes (Added, Changed, Fixed, Removed)
   - Reference issue/PR numbers if applicable
   - Date the release

3. **Update version references**:
   - `README.md` (installation instructions)
   - Any docs referencing specific versions

4. **Update example projects**:
   - Update `STACK.md` in each example: `Version: 0.2.5`
   - Test examples still work

5. **Git tag**:
   ```bash
   git tag -a v0.2.5 -m "Release v0.2.5: [brief description]"
   git push origin v0.2.5
   ```

6. **Create GitHub release** (manual in GitHub UI):
   - Copy CHANGELOG entry
   - Attach release notes
   - GitHub auto-creates release packages

**Semantic Versioning**:
- **Major (1.0.0)**: Breaking changes, incompatible with old projects
- **Minor (0.2.0)**: New features, backward compatible
- **Patch (0.2.1)**: Bug fixes, no new features

---

### 6. **Template Changes Require Careful Thought**

**Templates are copied to user projects**. Changes affect all future projects and upgrades.

**Before changing templates**:
1. **Consider backward compatibility**: Can old projects upgrade?
2. **Update upgrade.sh if needed**: Handle migration from old → new structure
3. **Update validation**: `validate_specs.py`, `doctor.py` must handle new structure
4. **Document breaking changes**: In CHANGELOG.md and UPGRADING.md

**Template files**:
- `.agentic/init/*.template.md` - Initial project files
- `.agentic/spec/*.template.md` - Spec document structures

**When changing template structure**:
1. Update the template
2. Update spec schema (if JSON/YAML structure changed)
3. Update validation scripts
4. Test in scratch project
5. Update examples to use new structure
6. Update UPGRADING.md if breaking
7. Consider backward compat in upgrade.sh

---

### 7. **Principles Are Sacred**

**`PRINCIPLES.md` is the framework's constitution**. Changes require strong justification.

**When proposing changes to principles**:
1. Explain what principle to change and why
2. Show what problem current principle causes
3. Demonstrate new principle aligns with core philosophy
4. Get user approval before implementing
5. Update all docs referencing the principle

**Adding new principles**:
- Should emerge from real experience, not theory
- Should have clear "What, Why, How, Example, Anti-pattern"
- Should fit existing structure

**Anti-pattern**: ❌ Changing principles based on single use case. ❌ Adding principles that contradict core philosophy.

---

### 8. **Framework Documentation Audience**

Different docs serve different readers:

**For framework users** (developers using framework in their projects):
- `README.md` - Overview and installation
- `START_HERE.md` - Quick orientation
- `DEVELOPER_GUIDE.md` - Daily usage
- `PRINCIPLES.md` - Understanding "why"
- `USER_WORKFLOWS.md` - Working with agents
- `MANUAL_OPERATIONS.md` - Token-free operations

**For agents working in user projects**:
- `agent_operating_guidelines.md` - Core rules
- `tdd_mode.md` - TDD workflow
- `continuous_quality_validation.md` - Quality practices
- `programming_standards.md` - Code quality
- `testing_standards.md` - Test quality

**For framework developers** (working ON framework):
- **This file** (`FRAMEWORK_DEVELOPMENT.md`)
- `PRINCIPLES.md` - Core values
- `CHANGELOG.md` - Version history
- `UPGRADING.md` - Upgrade process

**For framework contributors**:
- `PRINCIPLES.md` - Understanding philosophy
- This file - Development process
- Example projects - See it in action

**Rule**: Know your audience. User-facing docs shouldn't discuss framework internals. Framework dev docs shouldn't be in release package.

---

### 9. **Quality Standards Apply to Framework**

The framework must follow its own quality standards:

**Code quality**:
- ✅ Python scripts follow programming_standards.md
- ✅ Shell scripts are POSIX-compatible where possible
- ✅ Clear error messages (actionable, not cryptic)
- ✅ Fail fast with clear diagnostics

**Documentation quality**:
- ✅ Accurate (reflects reality, tested)
- ✅ Clear (no ambiguity)
- ✅ Comprehensive (covers all use cases)
- ✅ Consistent (terminology, style)
- ✅ Single source of truth (no duplication)

**Testing**:
- ✅ Test scripts in scratch projects
- ✅ Verify examples work
- ✅ Test upgrade paths
- ✅ Manual verification (no unit tests for framework yet)

**Anti-pattern**: ❌ "Do as I say, not as I do" - framework violating its own principles.

---

### 10. **Git Workflow for Framework**

**Branch strategy**:
- `main` - Stable, released versions
- Feature branches for significant changes (optional)
- Tag releases: `v0.2.5`

**Commit messages**:
Follow conventional commits:
```
type(scope): description

Body explaining what and why (optional)
```

**Types**:
- `feat`: New feature (minor version bump)
- `fix`: Bug fix (patch version bump)
- `docs`: Documentation only
- `refactor`: Code restructuring, no behavior change
- `test`: Adding/updating tests
- `chore`: Build process, dependencies

**Examples**:
```
feat(quality): add mutation testing support
fix(upgrade): handle missing VERSION file gracefully
docs(principles): clarify "shipped ≠ accepted" concept
refactor(docs): eliminate documentation duplication
```

**Before pushing**:
1. ✅ Test changes in scratch project
2. ✅ Update examples if needed
3. ✅ Update documentation
4. ✅ Update CHANGELOG (for releases)
5. ✅ Run through user workflows manually

---

### 11. **Release Checklist**

**When releasing a new version**:

- [ ] All changes tested in scratch project
- [ ] Example projects updated and working
- [ ] Documentation accurate and up-to-date
- [ ] `VERSION` file updated
- [ ] `CHANGELOG.md` updated with all changes
- [ ] Installation instructions reference correct version
- [ ] All commits pushed to main
- [ ] Git tag created: `git tag -a v0.2.5 -m "Release 0.2.5"`
- [ ] Tag pushed: `git push origin v0.2.5`
- [ ] GitHub release created with CHANGELOG excerpt
- [ ] Release packages auto-generated by GitHub
- [ ] Installation tested from GitHub release
- [ ] Upgrade tested from previous version

**Post-release**:
- [ ] Start next version in CHANGELOG (## [Unreleased])
- [ ] Update README version if showing "latest"

---

### 12. **Common Framework Development Patterns**

**Adding a new workflow document**:
1. Create `.agentic/workflows/new_workflow.md`
2. Link from `agent_operating_guidelines.md` if agents should follow it
3. Link from `DEVELOPER_GUIDE.md` if users should know about it
4. Add example to relevant example project
5. Update `START_HERE.md` document index if major workflow

**Adding a new tool script**:
1. Create `.agentic/tools/new_tool.sh` or `.agentic/tools/new_tool.py`
2. Add shebang and error handling
3. Add help text (`-h` flag)
4. Test in scratch project
5. Document in `DEVELOPER_GUIDE.md` (comprehensive)
6. Add quick example to `MANUAL_OPERATIONS.md` (if token-free info retrieval)
7. Update `START_HERE.md` tools list

**Adding a new agent role**:
1. Create `.agentic/agents/[role]/README.md`
2. Define what agent loads/doesn't load (context budget)
3. Define handoff protocol (input/output)
4. Update `sequential_agent_specialization.md`
5. Update `automatic_sequential_pipeline.md`
6. Test with real feature in example project
7. Document in `USER_WORKFLOWS.md`

**Changing existing template**:
1. Update `.agentic/init/*.template.md` or `.agentic/spec/*.template.md`
2. Update validation (`validate_specs.py`, `doctor.py`)
3. Update upgrade.sh for migration (if breaking)
4. Update examples to new structure
5. Test scaffold.sh creates correct files
6. Test upgrade from old → new
7. Document in CHANGELOG (if breaking: major/minor version bump)

---

## Framework Development Anti-Patterns

### ❌ Don't Change Templates Without Testing

**Why wrong**: Breaks all future projects and upgrades.

**Correct**: Test in scratch project, test upgrade path, update examples.

---

### ❌ Don't Update Docs Without Verifying Accuracy

**Why wrong**: Inaccurate docs are worse than no docs.

**Correct**: Test every code example, verify every workflow, check every link.

---

### ❌ Don't Duplicate Documentation

**Why wrong**: Update in 3 places = errors, maintenance burden.

**Correct**: Single source of truth with cross-references.

---

### ❌ Don't Break Backward Compatibility Casually

**Why wrong**: Existing projects can't upgrade, users lose trust.

**Correct**: Consider compatibility, provide upgrade path, document breaking changes.

---

### ❌ Don't Add Features Without Use Case

**Why wrong**: Framework bloat, confusing users, maintenance burden.

**Correct**: Real problem → solution → test in examples → release.

---

### ❌ Don't Commit Without Testing

**Why wrong**: Broken framework blocks all users.

**Correct**: Test in scratch project, update examples, verify workflows.

---

### ❌ Don't Release Without Updating CHANGELOG

**Why wrong**: Users don't know what changed, can't track regressions.

**Correct**: Every release has complete, dated CHANGELOG entry.

---

### ❌ Don't Violate Framework's Own Principles

**Why wrong**: "Do as I say, not as I do" kills credibility.

**Correct**: Framework follows its own quality, testing, documentation standards.

---

## Quick Reference: "I'm changing..."

**"...a template"**:
→ Test scaffold, update examples, test upgrade, check validation

**"...agent guidelines"**:
→ Test with example project, verify agent follows new rules, update principles if needed

**"...a workflow doc"**:
→ Walk through workflow manually, update examples, verify agent can follow it

**"...documentation"**:
→ Verify accuracy, check for duplication, test all examples/commands

**"...a tool script"**:
→ Test in scratch project, update DEVELOPER_GUIDE, verify error handling

**"...core principles"**:
→ Strong justification, user approval, update all references

**"...version number"**:
→ Full release checklist (see above)

---

## Getting Help

**Unsure about a change?**
1. Read `PRINCIPLES.md` - does change align with core philosophy?
2. Check example projects - would this improve or complicate them?
3. Ask user for guidance - provide options with pros/cons

**Found a problem?**
1. Document it clearly (what's wrong, why it's wrong)
2. Propose solution aligned with principles
3. Test solution in scratch project
4. Implement with examples and docs

**Making significant change?**
1. Explain what and why to user
2. Show before/after impact
3. Get approval before implementing
4. Test thoroughly
5. Update all affected areas

---

## Summary: Framework Development vs. Project Development

| Aspect | Project Development | Framework Development |
|--------|-------------------|---------------------|
| Scope | Single project | Framework + examples |
| Testing | Project tests | Scratch projects, examples |
| Docs | Project docs | User docs + framework dev docs |
| Changes | Affect one project | Affect all future projects |
| Quality | Follow standards | SET the standards |
| Releases | Project milestones | Semantic versions, CHANGELOG |
| Backward compat | Not critical | Very important |
| Examples | Optional | Mandatory |

**The Golden Rule**: Framework changes affect everyone using it. Test thoroughly, document accurately, maintain consistency, respect principles.

---

**Last Updated**: 2026-01-03  
**Framework Version**: 0.2.4  

**Note**: These guidelines evolve with the framework. When they change, notify framework contributors and update this document.

