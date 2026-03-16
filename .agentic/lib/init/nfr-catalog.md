---
summary: "NFR suggestions by project type for guided discovery during init"
trigger: "ag nfr discover, init playbook Step 2c"
tokens: ~1800
phase: planning
---

# NFR Catalog — Quality Constraints by Project Type

**Purpose**: Suggest relevant Non-Functional Requirements during project initialization. Developer picks and customizes thresholds — nothing is auto-applied.

**Usage**: Agent reads STACK.md `Primary platform:` and presents the relevant section. Developer selects applicable NFRs and adjusts thresholds. Selected NFRs are written to `.agentic/spec/NFR.md`.

**Priority tiers**: P1 = always include in recommendations, P2 = include when component/context matches, P3 = structural/CI-only (omitted from `ag nfr discover` unless `--all`).

---

## Universal (all project types)

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| U-01 | maintainability | Code files should stay under {threshold} lines | `wc -l` on source files | Pre-commit advisory | P1 |
| U-02 | maintainability | Test coverage should be above {threshold}% for critical paths | Coverage tool (pytest-cov, c8, etc.) | CI or manual | P1 |
| U-03 | reliability | All public functions must have error handling for invalid inputs | Code review + tests | Tests | P2 |
| U-04 | documentation | Public APIs must have docstrings/comments | Linter rules | CI | P2 |

**Customizable defaults**: U-01: 500 lines, U-02: 80%

---

## Web App

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| W-01 | performance | Largest Contentful Paint (LCP) must be under {threshold}ms | Lighthouse, Web Vitals | CI or manual audit | P1 |
| W-02 | performance | JavaScript bundle size must stay under {threshold}KB | Build output, bundlesize | CI | P1 |
| W-03 | accessibility | Pages must meet WCAG {level} compliance | axe-core, Lighthouse | CI or E2E | P1 |
| W-04 | security | No XSS vulnerabilities in user input handling | OWASP ZAP, manual review | Tests + code review | P1 |
| W-05 | security | CSRF protection on all state-changing endpoints | Framework middleware | Tests | P2 |
| W-06 | performance | Time to Interactive (TTI) under {threshold}ms | Lighthouse | CI | P2 |

**Customizable defaults**: W-01: 2500ms, W-02: 250KB, W-03: AA, W-06: 3500ms

---

## API / Backend

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| A-01 | performance | API response time p95 must be under {threshold}ms | Load testing (k6, locust) | CI or staging | P1 |
| A-02 | reliability | Service availability SLO of {threshold}% | Uptime monitoring | Ops | P1 |
| A-03 | security | Rate limiting on all public endpoints | Load test + config review | Tests | P1 |
| A-04 | security | Authentication required on all non-public endpoints | Route audit | Tests | P2 |
| A-05 | reliability | Graceful degradation when dependencies are unavailable | Chaos testing / mocks | Tests | P2 |
| A-06 | data | Database migrations must be reversible | Migration tool review | Code review | P1 |

**Customizable defaults**: A-01: 200ms, A-02: 99.9%

---

## Game

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| G-01 | performance | Frame rate must stay above {threshold} FPS | Profiler, frame counter | Manual testing | P1 |
| G-02 | performance | Input latency must be under {threshold}ms | Profiler | Manual testing | P1 |
| G-03 | performance | Memory budget must stay under {threshold}MB | Profiler | Manual testing | P1 |
| G-04 | performance | Loading time must be under {threshold}s | Timer | Manual testing | P2 |
| G-05 | reliability | No crashes during normal gameplay sessions | Automated playthrough | Smoke tests | P1 |

**Customizable defaults**: G-01: 60 FPS, G-02: 16ms, G-03: 512MB, G-04: 5s

---

## Mobile

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| M-01 | performance | App startup time must be under {threshold}s | Profiler | CI or manual | P1 |
| M-02 | performance | Memory usage must stay under {threshold}MB | Instruments/Profiler | Manual testing | P1 |
| M-03 | performance | Battery drain must stay under {threshold}%/hour during active use | Battery profiling | Manual testing | P2 |
| M-04 | reliability | App must function offline for core features | Manual testing | Tests | P2 |
| M-05 | performance | UI must respond to touch within {threshold}ms | Profiler | Manual testing | P1 |

**Customizable defaults**: M-01: 2s, M-02: 150MB, M-03: 5%, M-05: 100ms

---

## Audio / DSP

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| D-01 | realtime-safety | No heap allocations on audio thread | Static analysis, profiler | Code review + tests | P1 |
| D-02 | performance | Audio processing CPU budget must stay under {threshold}% | Profiler | Manual testing | P1 |
| D-03 | performance | Audio latency must be under {threshold}ms | DAW measurement | Manual testing | P1 |
| D-04 | reliability | Zero audio glitches during normal operation | Automated playback test | Tests | P1 |
| D-05 | realtime-safety | No locks, syscalls, or I/O on audio thread | Code review | Static analysis | P2 |

**Customizable defaults**: D-02: 50%, D-03: 10ms

---

## CLI

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| C-01 | performance | CLI startup time must be under {threshold}ms | time command | Tests | P1 |
| C-02 | reliability | Exit codes must follow conventions (0=success, 1=error, 2=usage) | Tests | Tests | P1 |
| C-03 | reliability | Must handle SIGINT/SIGTERM gracefully | Signal tests | Tests | P2 |
| C-04 | usability | Help text must be available for all commands | --help flag test | Tests | P1 |

**Customizable defaults**: C-01: 500ms

---

## Desktop

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| K-01 | performance | Application startup time must be under {threshold}s | Timer | Manual testing | P1 |
| K-02 | performance | Memory usage must stay under {threshold}MB at idle | Task manager / profiler | Manual testing | P1 |
| K-03 | performance | UI must respond within {threshold}ms to user actions | Profiler | Manual testing | P2 |
| K-04 | reliability | Must save state before unexpected termination | Crash handler | Tests | P1 |

**Customizable defaults**: K-01: 3s, K-02: 200MB, K-03: 100ms

---

## Library / SDK

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| L-01 | reliability | Public API must maintain backward compatibility within major versions | API diff tools (e.g., cargo-semver-checks, api-extractor) | CI | P1 |
| L-02 | maintainability | API surface must be minimal — no unnecessary public exports | Export audit, tree-shaking analysis | Code review | P1 |
| L-03 | performance | Must not add more than {threshold} transitive dependencies | Dependency tree analysis | CI | P1 |
| L-04 | documentation | All public types/functions must have usage examples | Doc linter, manual review | CI | P2 |
| L-05 | reliability | Must work across all declared supported platforms/runtimes | Cross-platform CI matrix | CI | P2 |

**Customizable defaults**: L-03: 10 transitive deps

---

## Data Pipeline

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| P-01 | data | Zero data loss — every input record must be accounted for in output | Reconciliation counts | Tests + monitoring | P1 |
| P-02 | reliability | Pipeline stages must be idempotent (safe to re-run) | Re-run tests with same input | Tests | P1 |
| P-03 | reliability | Pipeline must complete within {threshold} of SLA window | Duration monitoring | Ops | P1 |
| P-04 | data | Schema changes must be backward compatible with in-flight data | Schema validation | CI | P2 |
| P-05 | maintainability | Each pipeline stage must emit structured observability logs | Log audit | Tests | P2 |

**Customizable defaults**: P-03: 80% of SLA window

---

## Framework Promises (suggested for all projects using Agentic Framework)

| ID | Category | Statement | How to measure | Where enforced | Priority |
|----|----------|-----------|----------------|----------------|----------|
| F-01 | process | Commits must be small batches (max {threshold} files) | Pre-commit check | Git hooks | P3 |
| F-02 | process | Spec-first: acceptance criteria must exist before implementation code | Pre-commit + `ag implement` gate | Git hooks + ag.sh | P3 |
| F-03 | process | No auto-commits: human reviews every change | Agent instruction files | Agent behavior | P3 |
| F-04 | quality | Tests must exist for all shipped features | `ag done` checklist | Feature complete gate | P3 |

**Customizable defaults**: F-01: 10 files

---

## How to Use This Catalog

1. **During init** (Step 2c): Agent reads STACK.md `Primary platform:` and presents the matching section
2. **Automated**: `bash .agentic/lib/tools/nfr-generate.sh` outputs filtered recommendations
3. **Developer picks**: Select applicable NFRs, customize thresholds
4. **Agent writes**: Selected NFRs go to `.agentic/spec/NFR.md` with proper NFR-XXXX IDs
5. **Living document**: NFRs can be added/modified anytime via `ag nfr discover` or during retrospectives
6. **Profile behavior**:
   - **Formal**: NFRs link to acceptance criteria and are formally tracked
   - **Discovery**: NFRs serve as quality guidelines agents follow without formal spec linking
7. **Priority tiers**:
   - **P1**: Always recommend — customer-visible day-1 failures if missing
   - **P2**: Recommend when component/context matches — important but conditional
   - **P3**: Structural/CI-only — enforced by tooling, not feature-level ACs
