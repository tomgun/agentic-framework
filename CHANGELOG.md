# Changelog

All notable changes to the Agentic Framework will be documented in this file.

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

## [Unreleased]

### Planned
- Framework upgrade/migration tools
- npm package (optional install method)
- Homebrew formula (optional install method)
- More stack-specific quality profiles
- Enhanced dependency analysis
- Automated architecture documentation

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

