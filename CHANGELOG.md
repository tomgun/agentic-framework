# Changelog

All notable changes to the Agentic AI Framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-02

### Added (Initial Release)

**Core Framework:**
- Agent operating guidelines for consistent AI behavior
- Durable artifacts for token efficiency (CONTEXT_PACK, STATUS, JOURNAL)
- Specification system (PRD, Tech Spec, Features, NFR, ADR, Tasks)
- Feature tracking with stable IDs (F-####) and acceptance criteria
- Test-Driven Development (TDD) as recommended default mode
- Definition of done and quality review checklists

**Advanced Features:**
- Session continuity across context resets (JOURNAL.md)
- Feature dependency tracking with visualization
- Human escalation protocol (HUMAN_NEEDED.md)
- Architecture evolution tracking
- Research trails and structured research mode
- Automated retrospectives for project health checks
- Documentation verification to ensure up-to-date API usage
- Spec format validation with YAML frontmatter (optional)
- Continuous quality validation with stack-specific profiles
- Multi-agent coordination with Git worktrees
- PR workflow mode for team collaboration

**Tools (27 scripts):**
- Project health: `doctor.py`, `report.py`, `verify.sh`, `validate_specs.py`
- Context & analysis: `brief.sh`, `dashboard.sh`, `coverage.sh`, `feature_graph.sh`
- Manual operations: `search.sh`, `whatchanged.sh`, `deps.sh`, `accept.sh`
- Quality: `consistency.sh`, `stale.sh`, `retro_check.sh`, `version_check.sh`
- Development: `task.sh`, `sync_docs.sh`, `arch_diff.sh`

**Quality Profiles:**
- Web applications (bundle size, Lighthouse, accessibility)
- Mobile apps (iOS, Android - battery, memory, UI performance)
- Backend services (load testing, connection pools, queries)
- Desktop applications (Qt, Electron, native - UI responsiveness, cross-platform)
- CLI/Server tools (long-running, signal handling, resource cleanup)
- Games (2D, Unity, Unreal - FPS, physics, assets)
- Audio plugins (JUCE - pluginval, DSP validation, realtime CPU/glitch detection)
- Specialized (security, network, embedded/IoT, ML)

**Documentation:**
- Comprehensive README with design principles
- START_HERE guide for quick navigation
- FRAMEWORK_MAP with visual diagram
- MANUAL_OPERATIONS for token-free queries
- DIRECT_EDITING workflow for human spec editing
- 40+ workflow and guideline documents

**Stack Profiles:**
- Generic/default, Webapp fullstack, Native iOS
- Go backend, Python ML, Rust systems, React Native

### Features by Category

**Token Economics:**
- Structured reading protocols with explicit budgets
- Context budgeting strategies
- Durable artifacts prevent repeated repo scanning

**Developer UX:**
- Agent does all initialization (no manual script running)
- Clear status at all times
- Human review required before commits (no auto-commit)
- Direct spec editing by humans (agents pick up changes)

**Quality by Design:**
- TDD recommended (tests first)
- Stack-specific quality gates
- Mandatory tests for new/changed logic
- Design for testability guidelines

**Traceability:**
- Code annotations link code to features (`@feature F-####`)
- Bidirectional linking (specs → code → tests)
- Test coverage tracking per feature

**Team Collaboration:**
- Git workflow modes (direct commits or pull requests)
- Multi-agent coordination with worktrees
- AGENTS_ACTIVE.md for coordination
- File lock protocol to prevent conflicts

## [0.2.1] - 2026-01-02

### Added
- **Installation script** (`install.sh`) for automated framework setup
  - Reads VERSION from framework repo
  - Copies `.agentic/` to target project
  - Updates `STACK.md` with framework version and install date
  - Shows clear next steps for agent initialization

### Changed
- **Profile selection moved to agent interview** (UX improvement)
  - Profile choice now part of `init_playbook.md` workflow
  - Agent explains Core vs Core+PM differences
  - Users make informed choice during initialization
  - Removed `--profile` argument from `install.sh` (simpler)
- **Upgrade script improvements**
  - Now reads VERSION from new framework and updates `STACK.md`
  - Fixed references from `agentic/` to `.agentic/`
- **Documentation improvements**
  - README.md updated with clearer installation instructions
  - Explicit reference to `init_playbook.md` for agent guidance
  - Removed confusion about when initialization is complete

### Fixed
- `STACK.template.md` version updated to 0.2.0 (was 0.1.0)
- Framework version now properly tracked in production projects

## [0.2.0] - 2026-01-02

### Added

**Modular Framework Profiles:**
- Two profiles: "Core" (minimal) and "Core + Product Management" (full specs)
- Core includes: quality standards, workflows, multi-agent, research, PRODUCT.md
- Core+PM adds: formal specs, feature tracking (F-####), STATUS.md, project metrics
- Profile-aware agents adapt behavior based on STACK.md profile field
- Easy upgrade path: `enable-product-management.sh` converts Core → Core+PM

**Hidden Framework Internals:**
- Moved `agentic/` → `.agentic/` for cleaner project root
- Framework files hidden, product files (STACK.md, STATUS.md, spec/, docs/) visible
- Optimized for agent efficiency and developer clarity

**PRODUCT.md (New Core File):**
- Lightweight planning document for Core mode
- Captures: what we're building, capabilities (checkboxes), technical approach, scope
- Serves as basis for formal specs when upgrading to Core+PM
- Agents update it as work progresses

**Programming & Testing Standards:**
- Comprehensive programming guidelines (naming, functions, error handling, security, performance, green coding)
- Detailed testing standards (happy path, edge cases, invalid input, time-based, concurrency, resource exhaustion, network failures)
- TDD remains recommended default approach
- Standards linked prominently in README files

**Mutation Testing (Optional):**
- Added mutation testing as advanced quality check
- Documentation in `test_strategy.md`
- Helper script: `mutation_test.sh` (auto-detects stack)
- Guidance on when to use (critical logic, suspicious coverage, post-bug-fix)
- Integration with quality profiles

**Framework Upgrade Mechanism:**
- `UPGRADING.md` guide with step-by-step instructions
- `upgrade.sh` tool runs from new framework download (ensures latest logic)
- Safe upgrade path: backup → update internals → preserve customizations
- Validates before/after with doctor.py

**Examples (Complete Rewrite):**
- `core_todo_cli/` - Python CLI demonstrating Core profile
- `core_pm_taskboard/` - Next.js app demonstrating Core+PM profile
- Realistic mid-development state (not empty templates)
- Full validation: all tools pass (doctor, verify, report)
- Comprehensive README with profile comparison table

**Documentation Improvements:**
- Updated all READMEs to reflect Core vs Core+PM modes
- Added programming/testing standards to prominent locations
- Clear upgrade instructions
- Examples show both profiles in action

### Changed
- `agentic/` directory renamed to `.agentic/` (breaking change, but simple rename)
- Agents now profile-aware (check `Profile:` in STACK.md)
- `scaffold.sh` accepts `--profile` argument
- `doctor.py` and `verify.py` are profile-aware (skip PM checks in Core mode)
- `report.py` and `accept.py` degrade gracefully if PM features disabled

### Fixed
- PM templates no longer contain concrete example IDs (F-0001, NFR-0001) that caused verify failures
- Core mode agents now work efficiently (don't try to read non-existent STATUS.md/spec/)
- `enable-product-management.sh` detects PRODUCT.md and provides conversion guidance

## [Unreleased]

### Planned
- npm package (optional install method)
- Homebrew formula (optional install method)
- More stack-specific quality profiles
- Enhanced dependency analysis
- Automated architecture documentation
- Framework version compatibility checks

---

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version: Breaking changes (requires migration)
- **MINOR** version: New features (backward compatible)
- **PATCH** version: Bug fixes (backward compatible)

## Download

Get the latest release: https://github.com/YOUR_USERNAME/agentic-framework/releases

```bash
# Download and extract
curl -L https://github.com/YOUR_USERNAME/agentic-framework/archive/refs/tags/v0.1.0.tar.gz | tar xz

# Copy into your project
cp -r agentic-framework-0.1.0/agentic ./
```

