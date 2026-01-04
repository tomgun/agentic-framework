# Quality Profiles

This directory contains stack-specific quality validation profiles.

Agents copy and customize these during project initialization to create `quality_checks.sh` at the project root.

# Quality Profiles

This directory contains stack-specific quality validation profiles.

Agents copy and customize these during project initialization to create `quality_checks.sh` at the project root.

## Available Profiles

### Web Applications
- **webapp_fullstack.sh** (todo) - Full-stack web app validation
- **webapp_frontend.sh** (todo) - Frontend-only validation

### Mobile
- **ios_app.sh** (todo) - iOS app validation
- **android_app.sh** (todo) - Android app validation
- **mobile_game.sh** (todo) - Mobile game validation

### Backend/Services
- **backend_rest_api.sh** (todo) - REST API service validation
- **backend_go.sh** (todo) - Go service validation
- **backend_python.sh** (todo) - Python service validation
- **backend_rust.sh** (todo) - Rust service validation

### Desktop Applications
- **desktop_app_qt.sh** (todo) - Qt desktop app validation
- **desktop_app_electron.sh** (todo) - Electron app validation
- **desktop_app_native.sh** (todo) - Native C++/C# desktop app validation

### CLI & Server Tools
- **cli_tool.sh** (todo) - Command-line tool validation
- **server_daemon.sh** (todo) - Background service/daemon validation
- **batch_processor.sh** (todo) - Batch processing tool validation

### Games
- **game_2d_web.sh** ✅ - 2D web game validation (Phaser, PixiJS)
- **game_2d_mobile.sh** ✅ - 2D mobile game validation (React Native, SpriteKit, libGDX)
- **game_unity.sh** ✅ - Unity game validation (2D and 3D)
- **unreal_game.sh** (todo) - Unreal Engine game validation
- **opengl_demo.sh** (todo) - OpenGL/WebGL demo validation

### Audio/DSP
- **juce_audio_plugin.sh** - JUCE VST/AU/AUv3 plugin validation (complete)
- **ios_audio_plugin.sh** (todo) - iOS AUv3 audio plugin validation

### Image/Video Processing
- **image_processing.sh** (todo) - Image filter/processing validation
- **video_processing.sh** (todo) - Video processing validation

### Specialized
- **security_software.sh** (todo) - Security software validation
- **network_software.sh** (todo) - Network application validation
- **embedded_iot.sh** (todo) - Embedded/IoT validation
- **ml_python.sh** (todo) - ML/Data Science validation

## Common Check Categories by Domain

### Audio/Real-time Processing
- DSP correctness (NaN/Inf, DC offset)
- CPU usage / Real-time safety
- Latency measurements
- Glitch detection
- Audio artifact detection

### Web Applications
- TypeScript/linting
- Unit/integration tests
- Bundle size
- Performance (Lighthouse)
- Accessibility
- Memory leak detection

### Mobile Apps
- Build validation
- Unit/UI tests
- Performance (FPS, hangs)
- Memory usage
- Battery impact
- Background behavior

### Games
- Frame rate consistency
- Physics stability
- Asset loading times
- Memory usage
- Determinism (for networked games)

### Backend Services
- Load testing
- Response time validation
- Connection pool handling
- Memory leak detection
- Database query performance

### Security Software
- Static analysis
- Fuzzing
- Timing attack detection
- Buffer overflow checks
- Dependency vulnerabilities

## How to Use

### During Init (Automatic)

Agent automatically:
1. Reads tech stack from `STACK.md`
2. Selects appropriate profile
3. Copies to project root as `quality_checks.sh`
4. Customizes thresholds
5. Creates supporting test scripts
6. Optionally sets up pre-commit hook

### Manual Setup

1. Copy profile to project root:
   ```bash
   cp .agentic/quality_profiles/juce_audio_plugin.sh quality_checks.sh
   ```

2. Customize thresholds in the script

3. Create supporting test scripts (see profile comments)

4. Run:
   ```bash
   bash quality_checks.sh --pre-commit   # Fast check
   bash quality_checks.sh --full         # Comprehensive check
   ```

5. Optional: Set up pre-commit hook

## Creating Custom Profiles

If your stack isn't covered:

1. Start with the closest profile
2. Identify stack-specific failure modes:
   - Audio: NaN/Inf, glitches, CPU overload, feedback
   - Web: Bundle size, performance, accessibility, memory leaks
   - Mobile: Battery drain, memory usage, UI jank, crashes
   - Backend: Response time, memory leaks, connection leaks, deadlocks
3. Add checks for each failure mode
4. Set appropriate thresholds
5. Document in comments

## See Also

- Continuous Quality Validation: `.agentic/workflows/continuous_quality_validation.md`
- Init Playbook: `.agentic/init/init_playbook.md`
- Stack Profiles: `.agentic/support/stack_profiles/`

