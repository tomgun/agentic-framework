# Init questions (canonical)

The agent should ask only what’s necessary to produce durable context artifacts.

## Product + scope
- What type of product is this: webapp / game / vstplugin / mobileapp / app+backend?
  - If game: 2D or 3D? What genre (puzzle, platformer, shooter, strategy, etc.)?
  - If game: Target platform (web, mobile, desktop)?
- What are we building (1–2 sentences)?
- Who is the user and what is the primary workflow?
- Success criteria (measurable if possible)?
- Non-goals (what we explicitly won't do now)?
- Is this trivial/standard, or do we need a research phase first?
  - If research is needed: list what to research and what "good" sources look like (papers, official docs, reference implementations).

## Constraints
- Platforms: web/mobile/desktop/CLI/service?
- Deployment environment: local only, cloud, on-prem?
- Compliance/security requirements (PII, SOC2, HIPAA, GDPR, etc.)?
- Performance/latency constraints?

## Tech stack
- Primary language(s)?
- Primary framework(s) / runtime(s)?
  - If 2D game (web): Phaser 3, PixiJS, Godot (HTML5 export), or custom?
  - If 2D game (mobile): SpriteKit (iOS), libGDX (Android), Unity, or Godot?
  - If 2D game (desktop): Godot, SFML, SDL2, Raylib, Bevy (Rust), or Macroquad (Rust)?
  - If 3D game: Unity, Unreal Engine, Godot, or OpenGL/custom engine?
  - If 3D demo: OpenGL, WebGL, or Three.js?
- Package/dependency manager choice?
- Data storage: DB type + hosting?
- Authn/authz approach (if needed)?
- External integrations (APIs, queues, payments, etc.)?
- For games: Physics library (if needed)? Matter.js, Box2D, Bullet, Godot built-in, etc.?
- For games: Visual effects library (if needed)? Particle systems, shader effects, Godot VFX?

## Architecture + boundaries
- High-level architecture style (monolith, modular monolith, services)?
- Key modules/components and their responsibilities?
- Where are the seams for testing/mocking?

## Testing (must be explicit)
- Unit test framework choice?
- Integration/E2E test approach (if any)?
- How tests are run locally and in CI (commands)?
- Test data strategy (fixtures, factories, containers)?
- Domain-specific testing/perf (if relevant):
  - VST/JUCE: audio I/O golden tests, host automation tests, realtime/perf budget tests
  - Games: determinism/replay tests, frame rate independence tests, perf budgets (60fps target?), input recording/replay
  - Mobile: device/simulator strategy, UI tests, crash/perf checks

## Agent Development Style

How do you want to work with AI agents?

a) **Single agent** (default) - One agent handles research, testing, coding, review
b) **Specialized agents** - Different agents for research, testing, coding, review
   - More context-efficient (each agent reads only what it needs)
   - Better for complex features with clear phases
   - Requires: pipeline setup, agent role definitions
c) **Parallel features** - Multiple agents on different features simultaneously
   - Requires: git worktrees, AGENTS_ACTIVE.md coordination
   - Best for: large projects with independent features
d) **Not sure** - Start with single agent, enable later

If (b) or (c): run `bash .agentic/tools/setup-agent.sh pipeline`

## Developer experience
- Lint/format standards (if any)?
- CI provider (GitHub Actions by default)?
- Branching/review process expectations?

## Repo conventions
- Where specs live: `/spec/`?
- Where ADRs live: `spec/adr/`?
- Where status lives: `STATUS.md`?
- Any naming conventions that matter?


