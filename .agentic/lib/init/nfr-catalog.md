---
summary: "NFR suggestions by project type for guided discovery during init"
trigger: "ag nfr discover, init playbook Step 2c"
tokens: ~1500
phase: planning
---

# NFR Catalog — Quality Constraints by Project Type

**Purpose**: Suggest relevant Non-Functional Requirements during project initialization. Developer picks and customizes thresholds — nothing is auto-applied.

**Usage**: Agent reads STACK.md `Primary platform:` and presents the relevant section. Developer selects applicable NFRs and adjusts thresholds. Selected NFRs are written to `.agentic/spec/NFR.md`.

---

## Universal (all project types)

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| U-01 | maintainability | Code files should stay under {threshold} lines | `wc -l` on source files | Pre-commit advisory |
| U-02 | maintainability | Test coverage should be above {threshold}% for critical paths | Coverage tool (pytest-cov, c8, etc.) | CI or manual |
| U-03 | reliability | All public functions must have error handling for invalid inputs | Code review + tests | Tests |
| U-04 | documentation | Public APIs must have docstrings/comments | Linter rules | CI |

**Customizable defaults**: U-01: 500 lines, U-02: 80%

---

## Web App

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| W-01 | performance | Largest Contentful Paint (LCP) must be under {threshold}ms | Lighthouse, Web Vitals | CI or manual audit |
| W-02 | performance | JavaScript bundle size must stay under {threshold}KB | Build output, bundlesize | CI |
| W-03 | accessibility | Pages must meet WCAG {level} compliance | axe-core, Lighthouse | CI or E2E |
| W-04 | security | No XSS vulnerabilities in user input handling | OWASP ZAP, manual review | Tests + code review |
| W-05 | security | CSRF protection on all state-changing endpoints | Framework middleware | Tests |
| W-06 | performance | Time to Interactive (TTI) under {threshold}ms | Lighthouse | CI |

**Customizable defaults**: W-01: 2500ms, W-02: 250KB, W-03: AA, W-06: 3500ms

---

## API / Backend

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| A-01 | performance | API response time p95 must be under {threshold}ms | Load testing (k6, locust) | CI or staging |
| A-02 | reliability | Service availability SLO of {threshold}% | Uptime monitoring | Ops |
| A-03 | security | Rate limiting on all public endpoints | Load test + config review | Tests |
| A-04 | security | Authentication required on all non-public endpoints | Route audit | Tests |
| A-05 | reliability | Graceful degradation when dependencies are unavailable | Chaos testing / mocks | Tests |
| A-06 | data | Database migrations must be reversible | Migration tool review | Code review |

**Customizable defaults**: A-01: 200ms, A-02: 99.9%

---

## Game

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| G-01 | performance | Frame rate must stay above {threshold} FPS | Profiler, frame counter | Manual testing |
| G-02 | performance | Input latency must be under {threshold}ms | Profiler | Manual testing |
| G-03 | performance | Memory budget must stay under {threshold}MB | Profiler | Manual testing |
| G-04 | performance | Loading time must be under {threshold}s | Timer | Manual testing |
| G-05 | reliability | No crashes during normal gameplay sessions | Automated playthrough | Smoke tests |

**Customizable defaults**: G-01: 60 FPS, G-02: 16ms, G-03: 512MB, G-04: 5s

---

## Mobile

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| M-01 | performance | App startup time must be under {threshold}s | Profiler | CI or manual |
| M-02 | performance | Memory usage must stay under {threshold}MB | Instruments/Profiler | Manual testing |
| M-03 | performance | Battery drain must stay under {threshold}%/hour during active use | Battery profiling | Manual testing |
| M-04 | reliability | App must function offline for core features | Manual testing | Tests |
| M-05 | performance | UI must respond to touch within {threshold}ms | Profiler | Manual testing |

**Customizable defaults**: M-01: 2s, M-02: 150MB, M-03: 5%, M-05: 100ms

---

## Audio / DSP

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| D-01 | realtime-safety | No heap allocations on audio thread | Static analysis, profiler | Code review + tests |
| D-02 | performance | Audio processing CPU budget must stay under {threshold}% | Profiler | Manual testing |
| D-03 | performance | Audio latency must be under {threshold}ms | DAW measurement | Manual testing |
| D-04 | reliability | Zero audio glitches during normal operation | Automated playback test | Tests |
| D-05 | realtime-safety | No locks, syscalls, or I/O on audio thread | Code review | Static analysis |

**Customizable defaults**: D-02: 50%, D-03: 10ms

---

## CLI

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| C-01 | performance | CLI startup time must be under {threshold}ms | time command | Tests |
| C-02 | reliability | Exit codes must follow conventions (0=success, 1=error, 2=usage) | Tests | Tests |
| C-03 | reliability | Must handle SIGINT/SIGTERM gracefully | Signal tests | Tests |
| C-04 | usability | Help text must be available for all commands | --help flag test | Tests |

**Customizable defaults**: C-01: 500ms

---

## Desktop

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| K-01 | performance | Application startup time must be under {threshold}s | Timer | Manual testing |
| K-02 | performance | Memory usage must stay under {threshold}MB at idle | Task manager / profiler | Manual testing |
| K-03 | performance | UI must respond within {threshold}ms to user actions | Profiler | Manual testing |
| K-04 | reliability | Must save state before unexpected termination | Crash handler | Tests |

**Customizable defaults**: K-01: 3s, K-02: 200MB, K-03: 100ms

---

## Framework Promises (suggested for all projects using Agentic Framework)

| ID | Category | Statement | How to measure | Where enforced |
|----|----------|-----------|----------------|----------------|
| F-01 | process | Commits must be small batches (max {threshold} files) | Pre-commit check | Git hooks |
| F-02 | process | Spec-first: acceptance criteria must exist before implementation code | Pre-commit + `ag implement` gate | Git hooks + ag.sh |
| F-03 | process | No auto-commits: human reviews every change | Agent instruction files | Agent behavior |
| F-04 | quality | Tests must exist for all shipped features | `ag done` checklist | Feature complete gate |

**Customizable defaults**: F-01: 10 files

---

## How to Use This Catalog

1. **During init** (Step 2c): Agent reads STACK.md `Primary platform:` and presents the matching section
2. **Developer picks**: Select applicable NFRs, customize thresholds
3. **Agent writes**: Selected NFRs go to `.agentic/spec/NFR.md` with proper NFR-XXXX IDs
4. **Living document**: NFRs can be added/modified anytime via `ag nfr discover` or during retrospectives
5. **Profile behavior**:
   - **Formal**: NFRs link to acceptance criteria and are formally tracked
   - **Discovery**: NFRs serve as quality guidelines agents follow without formal spec linking
