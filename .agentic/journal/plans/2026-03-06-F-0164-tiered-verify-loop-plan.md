# E2E Testing in the Verify Loop

## Context

The verify loop (F-0161, `.agentic/lib/auto/verify.py`) runs a single test command in a fix-loop. It has no concept of test tiers. But real projects need multiple test levels, and "e2e" means different things per project type:

- **Web app + backend**: Playwright UI tests (visual) + API endpoint tests (non-visual) — both are e2e
- **VST plugin**: DSP audio validation (non-visual) + plugin UI tests (visual)
- **Backend/API**: endpoint smoke tests, no visual
- **CLI tool**: command execution tests, no visual

A single project can have BOTH visual and non-visual e2e tiers. Visual verification is per-tier (based on whether that tier produces screenshots), not per-project.

**Goal**: Extend the verify loop to support an ordered list of named test tiers, with per-tier visual verification for tiers that produce screenshots. Help production projects set up appropriate e2e tests.

---

## Delivery Structure

Three PRs, each self-contained:
- **PR1** (Phase 1+2): Tiered verify loop + STACK.md config — the core value
- **PR2** (Phase 3): Visual verification — screenshot collection + AI review in autonomous mode
- **PR3** (Phase 4): Scaffolding — detection, setup guide, quality profiles

---

## Phase 1: Tiered Verify Loop (PR1)

**Primary file**: `.agentic/lib/auto/verify.py`

### 1a. Add `TestTier` dataclass

```python
@dataclass
class TestTier:
    name: str                        # "unit", "integration", "e2e", "e2e-api", "dsp", any custom
    command: str                     # Shell command to run
    timeout: int = 120               # Seconds (default 120, suggest 300 for e2e)
    max_fix_iterations: int = 5      # Fix attempts for this tier
    continue_on_failure: bool = False # If True, next tier still runs on failure
```

**Simplified from original design**: Dropped `tier_level` (use list ordering instead), dropped server lifecycle fields (let e2e frameworks handle this — see rationale below), dropped `screenshot_dir` (deferred to Phase 3).

**Execution model**: Tiers run in declared order (position in STACK.md list = execution order). By default, a tier failure stops execution (fast-fail). If `continue_on_failure` is true, the next tier still runs. This replaces the complex tier-level system.

Example: Unit fails -> stop. But E2E API fails -> still run E2E UI (both have `continue_on_failure: true`).

### 1b. `_detect_test_tiers()` — replaces `_detect_test_command()`

Parse STACK.md `Test commands:` section for backtick-delimited commands:

```
Test commands:
  - Unit: `npm run test`
  - Integration: `npm run test:integration`
  - E2E API: `pytest tests/e2e/api/`
  - E2E UI: `npx playwright test`
```

**Parsing precedence** (backward compatible):
1. Look for `Test commands:` section with indented `- Name: \`command\`` entries
2. If not found, look for old-format `Test runner:` / `Test command:` fields -> create single "unit" tier
3. If not found, file-based detection (pytest.ini, package.json, etc.) -> create single "unit" tier

**Robustness**: Accept commands with or without backticks. Filter out placeholders (`<!-- fill -->`, `N/A`, HTML comments). Reuse parsing approach from `settings.py` `_SETTING_LINE_RE`.

### 1c. Modify `run()` for sequential tier execution

```python
def run(self, max_iterations=10, ...) -> VerifyResult:
    for tier in self.tiers:
        tier_result = self._run_tier(tier)
        result.tier_results.append(tier_result)
        if not tier_result.success and not tier.continue_on_failure:
            break  # fast-fail: don't run subsequent tiers
    result.success = all(tr.success for tr in result.tier_results)
```

Each tier has its own fix loop (run tests -> Claude fix -> re-run, up to `max_fix_iterations`).

### 1d. Server lifecycle — DEFERRED, delegate to e2e frameworks

**Rationale**: Starting/stopping dev servers is the hardest part with the most edge cases (process groups, port conflicts, orphaned processes, platform differences). E2e frameworks already solve this:
- Playwright: `webServer` config in `playwright.config.ts`
- Cypress: `cypress-dev-server` plugin
- Any: `start-server-and-test` npm package

The framework documents this in the setup guide (Phase 4) rather than reimplementing it. Can be added as a future enhancement if demand exists.

### 1e. Tier-specific Claude fix prompts

Fix prompts vary by tier name:
- Names containing "unit" or "integration": "Fix the code so tests pass. Do NOT modify the tests."
- Names containing "e2e", "ui", "visual", "dsp": "Fix the application behavior. These tests simulate real usage." + larger output context (8000 chars vs 4000)
- Default: generic fix prompt

### 1f. Add Playwright/Cypress output parsers

```python
# Playwright: "X passed" / "X failed" / "X skipped"
# Cypress: "Tests: N, Passing: N, Failing: N"
```

Add alongside existing pytest, Jest, Go, Cargo parsers. Auto-detect format from output.

### 1g. Updated result types

```python
@dataclass
class TierResult:
    tier_name: str
    success: bool
    iterations_used: int
    tests_passed: int = 0
    tests_failed: int = 0

@dataclass
class VerifyResult:
    # Existing fields preserved for backward compatibility
    success: bool
    iterations_used: int          # sum of all tier iterations
    max_iterations: int
    test_command: str             # first tier's command (backward compat)
    final_test_output: str = ""
    final_tests_passed: int = 0
    final_tests_failed: int = 0
    # New
    tier_results: list[TierResult] = field(default_factory=list)
```

Old fields populated from aggregate of tier results for backward compatibility.

### 1h. CLI update

```
ag auto verify                    # runs all configured tiers
ag auto verify --tier unit        # run only matching tier
ag auto verify --tier e2e         # run only matching tier(s)
```

`--tier` does prefix matching: `--tier e2e` runs both `E2E API` and `E2E UI`.

### 1i. Update task.py

**File**: `.agentic/lib/auto/task.py` (imports VerifyLoop at line 27, uses at lines 187-192 and 265-269)

Update to work with the new tiered `VerifyResult`. The `VerifyLoop(test_command=...)` constructor shortcut must still work — if `test_command` is passed explicitly, it creates a single "default" tier.

---

## Phase 2: STACK.md Configuration (PR1)

**File**: `.agentic/lib/init/STACK.template.md` (lines 103-109)

Extend the Testing section to support multiple named tiers:

```markdown
## Testing (required)
- Unit test framework: <!-- e.g., pytest, vitest, go test -->
- Integration/E2E (optional): <!-- e.g., playwright, cypress -->
- Test commands:
  - Unit: `<!-- fill -->`
  - Integration: `<!-- fill or N/A -->`
  - E2E: `<!-- fill or N/A -->`
  <!-- Multiple e2e-level tiers: -->
  <!-- - E2E API: `pytest tests/e2e/api/` -->
  <!-- - E2E UI: `npx playwright test` -->
  <!-- - DSP: `python3 tests/dsp_validation.py` -->
```

**Real-world examples:**

Web app + backend:
```
  - Unit: `npm run test`
  - E2E API: `pytest tests/e2e/api/`
  - E2E UI: `npx playwright test`
```

VST plugin:
```
  - Unit: `cmake --build build && ctest`
  - DSP: `python3 tests/dsp_validation.py`
  - E2E UI: `python3 tests/plugin_ui_test.py`
```

Backend API:
```
  - Unit: `go test ./...`
  - E2E: `bash tests/e2e/smoke.sh`
```

---

## Phase 3: Visual Verification (PR2, separate feature)

Visual verification activates per-tier, not per-project. A tier that produces screenshots gets visual review. A tier that doesn't (API tests, DSP validation) does not.

### 3a. Screenshot collection

Add `screenshot_dir: str = ""` field to `TestTier`. After a tier runs, if `screenshot_dir` is set, scan it for images. Record paths in `TierResult.screenshots`. Copy to `.agentic/session/screenshots/<feature>/` for review.

Screenshot dir is configured in STACK.md per-tier or as a global E2E option:
```
<!-- E2E options (uncomment if using): -->
<!-- - E2E screenshots: test-results/ -->
```

### 3b. No framework-level pixel comparison

**Design decision**: Remove `visual.py` from the plan. Stdlib-only byte comparison of PNGs is unreliable (anti-aliasing, font rendering, timestamps produce false positives on every comparison). Instead:
- **E2e frameworks handle visual comparison natively** — Playwright `toHaveScreenshot()`, Cypress image-snapshot, etc. A visual regression shows up as a test failure in the tier's exit code.
- **The framework's role**: collect screenshots for human review and AI-powered review (3c), not do pixel comparison.

### 3c. AI-powered visual review (autonomous mode)

When `ag auto task F-XXXX --visual` (meaningful only for tiers with screenshots):
1. After e2e tests pass, screenshots from `screenshot_dir` are passed to Claude as images (multimodal)
2. Claude evaluates: "Does this look correct? Any visual bugs, broken layouts, missing elements?"
3. Visual concerns flagged in verification report (soft failure, not blocking)
4. If no screenshots exist (backend project), `--visual` is a no-op with a warning
5. This is F-0168 from the autonomous workflow analysis plan

### 3d. What "e2e" looks like per project type — mixed tiers

| Project Type | E2E Tiers | Which Have Screenshots? |
|-------------|-----------|------------------------|
| Web app + backend | `E2E UI` (Playwright) + `E2E API` (supertest) | UI only |
| VST audio plugin | `DSP` (audio validation) + `E2E UI` (plugin UI) | UI only |
| Full-stack SaaS | `E2E API` + `E2E UI` + `E2E Email` | UI only |
| API-only service | `E2E` (curl/httpie smoke) | None |
| CLI tool | `E2E` (bash tests) | None |
| Game (web) | `E2E Gameplay` (Playwright) | Yes |

---

## Phase 4: Scaffolding (PR3, separate feature)

### 4a. E2E detection in discover.py

**File**: `.agentic/lib/tools/discover.py`

Add `_detect_e2e_framework()`:
- Config files: `playwright.config.ts`, `cypress.config.ts`, `.detoxrc.js`, `wdio.conf.js`
- package.json devDeps: `@playwright/test`, `cypress`
- Include `e2e_framework` in discovery report JSON

### 4b. E2E setup guide — `.agentic/lib/quality/e2e_setup_guide.md`

Agent playbook with project-type-aware recommendations:

- **Web apps**: Playwright (recommended) or Cypress. Visual review: yes. Server: use Playwright's `webServer` config.
- **Backend/API**: supertest (Node), pytest+httpx (Python), or curl scripts. No visual. Server: start in test setup.
- **CLI tools**: bash scripts or bats-core. No visual. No server.
- **Mobile**: Detox (RN), XCUITest (iOS), Espresso (Android). Visual: yes.
- **Games (web)**: Playwright. Visual: yes. Server: use `webServer` config.
- **VST plugins**: DSP validation (custom Python/C++) + optional UI tests. Visual: UI tier only.

Each includes: install commands, example config, example test, STACK.md fields.

### 4c. E2E testing contract — `.agentic/lib/quality/e2e_testing_contract.md`

Documents the tool-agnostic contract:
1. A shell command that returns exit 0/non-zero
2. Parseable output (optional — falls back to exit code)
3. Screenshots in a known directory (optional)
4. Server management is the test's responsibility (not the framework's)

Known framework patterns:

| Framework | Command | Config | Screenshots |
|-----------|---------|--------|-------------|
| Playwright | `npx playwright test` | `playwright.config.ts` | `test-results/` |
| Cypress | `npx cypress run` | `cypress.config.ts` | `cypress/screenshots/` |
| Detox | `detox test` | `.detoxrc.js` | `artifacts/` |

### 4d. Init playbook update

**File**: `.agentic/lib/init/init_playbook.md`

After existing testing questions: if project has a UI framework, ask about e2e tests and suggest appropriate framework.

### 4e. Quality profiles

New: `.agentic/lib/quality_profiles/webapp_with_e2e.sh`
Existing profiles: add optional e2e step reading from STACK.md.

---

## Ideas (future, out of scope)

### Idea 1: Playwright MCP as Visual Debugger
When e2e fails in autonomous mode, Claude uses Playwright MCP to interactively navigate the app and investigate — not just read error output but look at the actual page.

### Idea 2: Screenshot-Driven Acceptance Criteria
ACs include reference screenshots. Claude's vision compares actual render against the AC image. Visual requirements become as verifiable as functional ones.

### Idea 3: Accessibility/Performance as Tiers
`npx playwright test --project=a11y`, Lighthouse CI, SEO checks — all just more test commands in the tier list.

### Idea 4: Video Recording for Flaky Tests
Save videos when tests pass on retry. Store in `.agentic/session/recordings/`.

### Idea 5: Cross-Browser/Device Matrix
STACK.md declares target browsers/devices. E2e tier runs across the matrix.

### Idea 6: Health Check as Minimal E2E
For backend services: `curl http://localhost:8080/health` as the simplest e2e starting point. Scaffolded as `tests/e2e/smoke.sh`. Graduate to full Playwright later.

### Idea 7: Server Lifecycle Management (future enhancement)
If enough projects need it: `_start_server()` / `_stop_server()` with port polling (not stdout matching), process group cleanup, PID files. For now, delegate to e2e framework config.

---

## Files Summary

### PR1 (Phase 1+2): Tiered Verify Loop

**Modified:**
| File | Change |
|------|--------|
| `.agentic/lib/auto/verify.py` | TestTier, tiered execution, new parsers, updated results |
| `.agentic/lib/auto/task.py` | Update VerifyLoop usage for new API |
| `.agentic/lib/init/STACK.template.md` | Multiple tier entries in Testing section |
| `.agentic/lib/auto/settings-template.json` | E2E runner permissions |

**New:**
| File | Purpose |
|------|---------|
| `tests/test_auto_verify_tiers.py` | Tests for tiered execution, parsing, backward compat |

### PR2 (Phase 3): Visual Verification

**Modified:**
| File | Change |
|------|--------|
| `.agentic/lib/auto/verify.py` | Add `screenshot_dir` to TestTier, screenshot collection |
| `.agentic/lib/auto/engine.py` | Add `--visual` flag, AI screenshot review step |

### PR3 (Phase 4): Scaffolding

**Modified:**
| File | Change |
|------|--------|
| `.agentic/lib/tools/discover.py` | `_detect_e2e_framework()` |
| `.agentic/lib/init/init_playbook.md` | E2E setup question |

**New:**
| File | Purpose |
|------|---------|
| `.agentic/lib/quality/e2e_testing_contract.md` | Tool-agnostic E2E contract |
| `.agentic/lib/quality/e2e_setup_guide.md` | Agent playbook for e2e setup |
| `.agentic/lib/quality_profiles/webapp_with_e2e.sh` | Quality profile with e2e |

---

## Verification

### PR1
1. `python3 -m pytest tests/test_auto_verify_tiers.py` — new tier tests
2. `python3 -m pytest tests/test_auto_verify.py` — existing tests still pass (backward compat)
3. `bash tests/validate_framework.sh` — framework validation
4. Manual: project with only `Unit:` in STACK.md -> works exactly as before
5. Manual: project with `Unit:` + `E2E:` -> runs unit first, then e2e

### PR2
1. Manual: configure `screenshot_dir`, run tiers, verify screenshots collected
2. Manual: `ag auto task F-XXXX --visual` on project with UI screenshots

### PR3
1. `bash tests/validate_framework.sh`
2. Manual: run discover.py on a project with Playwright installed, verify detection

---

## Feature Registration

- PR1: New feature F-XXXX "Tiered Verify Loop" in FEATURES.md
- PR2: F-0168 "Visual Verification" (already planned in autonomous analysis)
- PR3: Enhancement to existing F-0001 init / F-0161 verify — no new feature ID needed
