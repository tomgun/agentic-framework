# Continuous Quality Validation

**Purpose**: Automated, stack-specific quality gates that run before every commit to ensure production-ready code.

## Philosophy

**Every technology stack has specific failure modes.** Generic tests aren't enough:
- Web apps: Memory leaks, slow render, broken accessibility
- Mobile apps: Battery drain, UI jank, background crashes
- Backend services: Connection leaks, slow queries, cascade failures
- Desktop apps: Memory leaks, UI responsiveness, cross-platform issues
- CLI/Server tools: Memory leaks, signal handling, long-running stability
- Games: Frame drops, physics glitches, asset loading issues
- Audio plugins: NaN/Inf values, glitches, runaway feedback, zipper noise
- Real-time software: Missed deadlines, priority inversions
- Security software: Timing attacks, side channels, buffer overflows

**Solution**: Stack-specific quality validation profiles that catch technology-specific bugs automatically.

## Core Principles

1. **Stack-Specific**: Quality checks match your technology
2. **Automated**: Run before commit, no human judgment needed
3. **Fast Enough**: <2 min for pre-commit, comprehensive suite in CI
4. **Fail Fast**: Block commits if critical checks fail
5. **Living Standard**: Updated during retrospectives as project evolves

## How It Works

### Phase 1: Initialization (Agent-Driven)

When initializing project, agent:
1. **Reads tech stack** from init questions
2. **Selects quality profile** (or creates custom)
3. **Creates `quality_checks.sh`** with stack-specific tests
4. **Sets up pre-commit hook** (optional but recommended)
5. **Documents in STACK.md**

### Phase 2: Continuous Validation

Before every commit:
```bash
# Pre-commit hook runs automatically
bash quality_checks.sh --pre-commit

# Or run manually
bash quality_checks.sh --full
```

### Phase 3: Evolution (Retrospective)

During retrospectives, agent:
1. **Reviews quality check failures** (if any)
2. **Suggests new checks** based on bugs found
3. **Updates `quality_checks.sh`**
4. **Documents in retrospective report**

## Stack-Specific Profiles

Each technology has unique failure modes. Quality profiles target these specifically.

### Quick Examples by Stack

| Stack Type | Key Quality Checks | Example Failure Modes |
|------------|-------------------|----------------------|
| **Web App** | Bundle size, Lighthouse, accessibility | Memory leaks, slow render, poor a11y |
| **Mobile App** | Battery, memory, UI performance | Battery drain, jank, crashes |
| **Backend Service** | Load testing, connection pools, queries | Connection leaks, slow queries, deadlocks |
| **Desktop App** | UI responsiveness, memory, cross-platform | UI freezes, memory leaks, platform bugs |
| **CLI/Server Tool** | Memory, signal handling, long-running | Memory leaks, zombie processes, crashes |
| **Game (2D/3D)** | FPS, physics, asset loading | Frame drops, physics bugs, long loads |
| **Audio Plugin** | pluginval, DSP validation, CPU/glitch detection | NaN/Inf, glitches, zipper noise, feedback |
| **Real-time System** | Deadline analysis, jitter | Missed deadlines, priority inversions |
| **Security Software** | Static analysis, fuzzing, timing | Buffer overflows, timing attacks |
| **Network Software** | Connection handling, throughput | Connection leaks, packet loss |

### Detailed Examples

For complete implementations, see `.agentic/quality_profiles/`:
- Web applications: `webapp_fullstack.sh`
- Backend services: `backend_service.sh`
- Mobile apps: `ios_app.sh`, `android_app.sh`
- Desktop applications: `desktop_app.sh`
- CLI/Server tools: `cli_server_tool.sh`
- Games: `game_engine.sh`
- Audio plugins (JUCE): `juce_audio_plugin.sh` - includes pluginval, offline DSP validation with numpy, realtime CPU & glitch detection
- Audio plugins (raw VST3 SDK): `raw_vst3_plugin.sh` - for projects using Steinberg VST3 SDK directly without JUCE/iPlug2
- More examples in the profiles directory

Below are conceptual examples showing the approach for different stacks.

### Example: Web Application

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Web Application Quality Validation ==="
echo

# 1. Build check
echo "1. Build validation..."
cmake --build build --config Release
if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi
echo "✅ Build successful"
echo

# 2. Pluginval (smoke test)
echo "2. Running pluginval smoke test..."
pluginval --validate --strictness-level 5 \
  --validate-in-process \
  --skip-gui-tests \
  --output-dir validation_results \
  build/MyPlugin_artefacts/Release/VST3/MyPlugin.vst3

if [ $? -ne 0 ]; then
  echo "❌ Pluginval failed"
  exit 1
fi
echo "✅ Pluginval passed"
echo

# 3. Offline audio render test
echo "3. Running offline audio DSP validation..."
python3 scripts/test_dsp_validation.py \
  --plugin build/MyPlugin_artefacts/Release/VST3/MyPlugin.vst3 \
  --input test_audio/sine_440hz.wav \
  --output test_output/result.wav \
  --expected test_audio/expected_output.wav \
  --tolerance 0.001

if [ $? -ne 0 ]; then
  echo "❌ DSP validation failed"
  exit 1
fi
echo "✅ DSP validation passed"
echo

# 4. Realtime performance benchmark
echo "4. Running realtime CPU & glitch detection..."
python3 scripts/test_realtime_performance.py \
  --plugin build/MyPlugin_artefacts/Release/VST3/MyPlugin.vst3 \
  --sample-rate 48000 \
  --buffer-size 512 \
  --duration 60 \
  --max-cpu-percent 50 \
  --detect-glitches \
  --detect-nan-inf \
  --detect-zipper \
  --detect-runaway

if [ $? -ne 0 ]; then
  echo "❌ Performance validation failed"
  exit 1
fi
echo "✅ Performance validation passed"
echo

echo "✅ All quality checks passed!"
```

**Supporting Scripts**:

**`scripts/test_dsp_validation.py`**:
```python
#!/usr/bin/env python3
"""Offline audio render with DSP validation."""

import numpy as np
import argparse
from pathlib import Path

def validate_audio(output_path: Path, expected_path: Path, tolerance: float) -> bool:
    """Validate rendered audio against expected output."""
    
    # Load audio files
    output = load_wav(output_path)
    expected = load_wav(expected_path)
    
    # Check for NaN/Inf
    if np.isnan(output).any():
        print("❌ Output contains NaN values")
        return False
    if np.isinf(output).any():
        print("❌ Output contains Inf values")
        return False
    
    # Check sample rate match
    if output.shape != expected.shape:
        print(f"❌ Shape mismatch: {output.shape} != {expected.shape}")
        return False
    
    # Check RMS difference
    diff = np.abs(output - expected)
    rms_diff = np.sqrt(np.mean(diff ** 2))
    
    if rms_diff > tolerance:
        print(f"❌ RMS difference {rms_diff} exceeds tolerance {tolerance}")
        return False
    
    print(f"✅ RMS difference: {rms_diff} (within tolerance)")
    return True

# ... (rest of implementation)
```

**`scripts/test_realtime_performance.py`**:
```python
#!/usr/bin/env python3
"""Realtime performance and glitch detection."""

import numpy as np
import time
from typing import Tuple

def test_realtime_performance(
    plugin_path: str,
    sample_rate: int,
    buffer_size: int,
    duration: int,
    max_cpu_percent: float
) -> bool:
    """Test plugin under realtime constraints."""
    
    results = {
        'max_cpu': 0.0,
        'avg_cpu': 0.0,
        'glitches': 0,
        'nans': 0,
        'infs': 0,
        'discontinuities': 0,
        'zipper_noise': False,
        'runaway_feedback': False
    }
    
    # Process audio in realtime simulation
    num_buffers = int((sample_rate * duration) / buffer_size)
    
    for i in range(num_buffers):
        # Generate test signal
        input_buffer = generate_test_signal(buffer_size, sample_rate)
        
        # Process with timing
        start = time.perf_counter()
        output_buffer = process_plugin(plugin_path, input_buffer)
        elapsed = time.perf_counter() - start
        
        # Calculate CPU usage
        cpu_percent = (elapsed / (buffer_size / sample_rate)) * 100
        results['max_cpu'] = max(results['max_cpu'], cpu_percent)
        results['avg_cpu'] += cpu_percent / num_buffers
        
        # Check for glitches (late processing)
        if cpu_percent > 100:
            results['glitches'] += 1
        
        # Check for NaN/Inf
        if np.isnan(output_buffer).any():
            results['nans'] += 1
        if np.isinf(output_buffer).any():
            results['infs'] += 1
        
        # Check for discontinuities (clicks)
        if i > 0:
            discontinuity = abs(output_buffer[0] - prev_last_sample)
            if discontinuity > 0.1:  # Threshold for click
                results['discontinuities'] += 1
        
        prev_last_sample = output_buffer[-1]
        
        # Check for zipper noise (parameter smoothing issues)
        if detect_zipper_noise(output_buffer):
            results['zipper_noise'] = True
        
        # Check for runaway feedback
        if np.max(np.abs(output_buffer)) > 10.0:  # Well above 0dB
            results['runaway_feedback'] = True
            break
    
    # Report results
    print(f"Max CPU: {results['max_cpu']:.1f}%")
    print(f"Avg CPU: {results['avg_cpu']:.1f}%")
    print(f"Glitches: {results['glitches']}")
    print(f"NaN samples: {results['nans']}")
    print(f"Inf samples: {results['infs']}")
    print(f"Discontinuities: {results['discontinuities']}")
    print(f"Zipper noise: {results['zipper_noise']}")
    print(f"Runaway feedback: {results['runaway_feedback']}")
    
    # Check thresholds
    if results['max_cpu'] > max_cpu_percent:
        print(f"❌ Max CPU {results['max_cpu']:.1f}% exceeds {max_cpu_percent}%")
        return False
    
    if results['glitches'] > 0:
        print(f"❌ {results['glitches']} glitches detected")
        return False
    
    if results['nans'] > 0 or results['infs'] > 0:
        print(f"❌ Invalid values detected")
        return False
    
    if results['runaway_feedback']:
        print(f"❌ Runaway feedback detected")
        return False
    
    return True

# ... (helper functions)
```

### Raw VST3 SDK Plugin (non-JUCE)

For projects using the Steinberg VST3 SDK directly without JUCE or iPlug2.

**Profile**: `.agentic/quality_profiles/raw_vst3_plugin.sh`

**Key differences from JUCE:**
- CMake-based build system (not Projucer)
- Different artifact paths: `build/VST3/Release/*.vst3`
- pluginval detection handles Homebrew Cask installs on macOS
- No JUCE-specific test infrastructure

**Why use raw VST3 SDK?**
- Avoid JUCE commercial license costs
- Minimal dependencies
- Full control over plugin architecture
- Custom OpenGL/Metal rendering without JUCE abstractions

**Typical project structure:**
```
project/
├── CMakeLists.txt
├── external/vst3sdk/          # VST3 SDK as submodule
├── src/
│   ├── processor.cpp          # Audio processing
│   ├── controller.cpp         # Parameter handling
│   └── view_mac.mm            # Platform-specific UI
├── build/
│   └── VST3/Release/*.vst3    # Build output
└── quality_checks.sh          # Generated from profile
```

**Example `quality_checks.sh` creation:**
```bash
cp .agentic/quality_profiles/raw_vst3_plugin.sh quality_checks.sh
chmod +x quality_checks.sh
# Customize thresholds as needed
```

**Stack detection patterns** (for auto-suggesting this profile):
- `external/vst3sdk/` or `libs/vst3sdk/` directory exists
- CMakeLists.txt contains `smtg_add_vst3plugin` or references VST3 SDK
- No JUCE or iPlug2 dependencies detected
- `.mm` files for macOS platform code (manual UI, not framework)

**STACK.md configuration:**
```markdown
## Quality validation (recommended)
- quality_checks: enabled
- profile: raw_vst3_plugin
- pre_commit_hook: no  # Enable when tests comprehensive
- run_command: bash quality_checks.sh --pre-commit
- full_suite_command: bash quality_checks.sh --full
- validation_tool: pluginval  # brew install --cask pluginval
```

**Reference implementation**: https://github.com/tomgun/vst-musializer

---

### Web Application (React/Next.js)

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Web Application Quality Validation ==="
echo

# 1. Type checking
echo "1. TypeScript type checking..."
npm run type-check
echo "✅ Types valid"
echo

# 2. Linting
echo "2. Linting..."
npm run lint
echo "✅ Linting passed"
echo

# 3. Unit tests
echo "3. Running unit tests..."
npm run test:unit -- --run
echo "✅ Unit tests passed"
echo

# 4. Build validation
echo "4. Production build..."
npm run build
echo "✅ Build successful"
echo

# 5. Bundle size check
echo "5. Checking bundle size..."
node scripts/check-bundle-size.js --max-size 500kb
echo "✅ Bundle size OK"
echo

# 6. Accessibility audit
echo "6. Running accessibility checks..."
npm run test:a11y
echo "✅ Accessibility passed"
echo

# 7. Performance audit (key pages)
echo "7. Running performance audit..."
node scripts/lighthouse-ci.js \
  --url http://localhost:3000 \
  --performance 90 \
  --accessibility 95 \
  --best-practices 90
echo "✅ Performance metrics met"
echo

# 8. Memory leak detection
echo "8. Checking for memory leaks..."
node scripts/test-memory-leaks.js
echo "✅ No memory leaks detected"
echo

echo "✅ All quality checks passed!"
```

echo "✅ All quality checks passed!"
```

echo "✅ All quality checks passed!"
```

### Example: Desktop Application

**Focus**: UI responsiveness, memory usage, cross-platform compatibility

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Desktop Application Quality Validation ==="
echo

# 1. Build for all platforms
echo "1. Build validation..."
# Linux
cmake --build build-linux --config Release
# macOS (if on macOS)
cmake --build build-macos --config Release
# Windows (if cross-compiling or on Windows)
# cmake --build build-windows --config Release

# 2. UI responsiveness test
echo "2. Testing UI responsiveness..."
python3 scripts/test_ui_responsiveness.py \
  --max-event-latency-ms 16 \
  --max-paint-time-ms 8 \
  --check-main-thread-blocking

# 3. Memory leak detection
echo "3. Checking for memory leaks..."
valgrind --leak-check=full \
  --error-exitcode=1 \
  --suppressions=valgrind.supp \
  ./build-linux/MyApp --run-tests

# 4. Cross-platform compatibility
echo "4. Testing cross-platform consistency..."
python3 scripts/test_platform_compatibility.py \
  --check-file-paths \
  --check-line-endings \
  --check-font-rendering

# 5. Resource usage
echo "5. Checking resource usage..."
python3 scripts/test_resource_usage.py \
  --max-memory-mb 200 \
  --max-cpu-idle-percent 5 \
  --check-file-handles

echo "✅ All quality checks passed!"
```

### Example: CLI/Server Tool

**Focus**: Long-running stability, memory leaks, signal handling, correctness

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== CLI/Server Tool Quality Validation ==="
echo

# 1. Build validation
echo "1. Build validation..."
go build -o bin/mytool ./cmd/mytool

# 2. Unit/integration tests
echo "2. Running tests..."
go test ./... -v -race

# 3. Long-running stability test
echo "3. Testing long-running stability..."
python3 scripts/test_long_running.py \
  --duration 300 \
  --check-memory-growth \
  --check-goroutine-leaks \
  --check-file-descriptor-leaks

# 4. Signal handling
echo "4. Testing signal handling..."
python3 scripts/test_signal_handling.py \
  --signals SIGTERM,SIGINT,SIGHUP \
  --check-graceful-shutdown \
  --max-shutdown-time-s 10

# 5. Correctness under load
echo "5. Testing correctness under load..."
python3 scripts/test_correctness.py \
  --concurrent-requests 100 \
  --duration 60 \
  --verify-output \
  --check-data-races

# 6. Resource cleanup
echo "6. Checking resource cleanup..."
python3 scripts/test_resource_cleanup.py \
  --check-temp-files \
  --check-connections \
  --check-child-processes

echo "✅ All quality checks passed!"
```

### Example: Mobile Game

**Focus**: Frame rate, physics stability, asset loading, memory

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Game Quality Validation ==="
echo

# 1. Build validation
echo "1. Build validation..."
# (build command for your engine)

# 2. FPS benchmark
echo "2. Running FPS benchmark..."
python3 scripts/test_fps_benchmark.py \
  --min-fps 60 \
  --max-frame-time-ms 16.67 \
  --duration 60

# 3. Physics stability test
echo "3. Testing physics stability..."
python3 scripts/test_physics_stability.py \
  --check-explosions \
  --check-tunneling \
  --check-determinism

# 4. Asset loading test
echo "4. Testing asset loading..."
python3 scripts/test_asset_loading.py \
  --max-load-time-ms 100 \
  --check-memory-leaks

# 5. Memory usage
echo "5. Checking memory usage..."
python3 scripts/test_memory_usage.py \
  --max-memory-mb 500 \
  --check-fragmentation

echo "✅ All quality checks passed!"
```

### Example: Backend Service

**Focus**: Response time, connection handling, memory leaks, load capacity

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Backend Service Quality Validation ==="
echo

# 1. Build & test
echo "1. Build validation..."
go build ./...
go test ./... -v

# 2. Load testing
echo "2. Running load test..."
vegeta attack \
  -targets=load_test_targets.txt \
  -rate=100/s \
  -duration=30s | vegeta report

# 3. Connection pool test
echo "3. Testing connection handling..."
python3 scripts/test_connection_pool.py \
  --max-connections 1000 \
  --check-leaks

# 4. Memory profiling
echo "4. Checking for memory leaks..."
go test -memprofile=mem.prof ./...
go tool pprof -top mem.prof | grep -i leak

# 5. Response time validation
echo "5. Validating response times..."
python3 scripts/test_response_times.py \
  --p50-max-ms 10 \
  --p95-max-ms 50 \
  --p99-max-ms 200

echo "✅ All quality checks passed!"
```

### Example: Real-time Demo Engine

**Focus**: Frame timing, rendering quality, shader compilation, audio sync

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Demo Engine Quality Validation ==="
echo

# 1. Build validation
echo "1. Build validation..."
# (build for your platform)

# 2. Frame timing analysis
echo "2. Analyzing frame timing..."
python3 scripts/test_frame_timing.py \
  --target-fps 60 \
  --max-jitter-ms 1.0 \
  --duration 60

# 3. Shader compilation
echo "3. Testing shader compilation..."
python3 scripts/test_shaders.py \
  --check-compilation \
  --check-warnings \
  --max-compile-time-ms 100

# 4. Rendering validation
echo "4. Validating rendering..."
python3 scripts/test_rendering.py \
  --capture-frames \
  --compare-golden-images \
  --tolerance 0.01

# 5. Audio sync test
echo "5. Testing audio synchronization..."
python3 scripts/test_audio_sync.py \
  --max-drift-ms 10 \
  --check-glitches

echo "✅ All quality checks passed!"
```

### Example: Security Software

**Focus**: Vulnerability detection, fuzzing, timing attacks, static analysis

**File**: `quality_checks.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Security Software Quality Validation ==="
echo

# 1. Static analysis
echo "1. Running static analysis..."
semgrep --config=p/security-audit \
  --severity=ERROR \
  --error

# 2. Fuzzing (quick run)
echo "2. Running fuzzer..."
afl-fuzz -i test_cases/ -o fuzz_output/ -t 1000 ./target &
FUZZ_PID=$!
sleep 30  # Quick 30s fuzz for pre-commit
kill $FUZZ_PID
python3 scripts/check_fuzz_results.py fuzz_output/

# 3. Timing attack detection
echo "3. Testing for timing attacks..."
python3 scripts/test_timing_attacks.py \
  --operations auth,crypto \
  --max-variance-ns 100

# 4. Buffer overflow checks
echo "4. Checking for buffer overflows..."
valgrind --leak-check=full \
  --error-exitcode=1 \
  ./run_test_suite

# 5. Dependency vulnerability scan
echo "5. Scanning dependencies..."
safety check --json | python3 scripts/check_vulnerabilities.py

echo "✅ All quality checks passed!"
```

### More Stack Examples

**See `.agentic/quality_profiles/` for complete implementations:**

- **Web apps**: Bundle size, performance, accessibility, memory
- **Mobile apps**: iOS/Android, battery, memory, UI performance
- **Backend services**: Load testing, connections, queries
- **Desktop apps**: Cross-platform (Linux/Mac/Windows), UI responsiveness, memory
- **CLI/Server tools**: Long-running stability, signal handling, resource cleanup
- **Games**: 2D, Unity, Unreal - FPS, physics, assets
- **Audio plugins**: JUCE VST/AU/AUv3 with pluginval, DSP validation (numpy), realtime metrics
- **Real-time demos**: Frame timing, shaders, audio sync
- **Image/video processing**: Quality, performance, color accuracy
- **Security software**: Static analysis, fuzzing, timing
- **Network software**: Connection handling, throughput, reliability
- **Embedded/IoT**: Memory footprint, power, real-time constraints

## Integration with Framework

### 1. Init Playbook Update

**File**: `.agentic/init/init_playbook.md`

Add step:

```markdown
## Step 5: Create Quality Validation Profile

**Agent should:**

1. **Identify tech stack** from previous questions
2. **Select or create quality profile**:
   - JUCE audio plugin → Use `juce_quality_profile.sh`
   - Web app (React/Next.js) → Use `webapp_quality_profile.sh`
   - iOS app → Use `ios_quality_profile.sh`
   - Custom → Create based on stack-specific risks
3. **Create `quality_checks.sh`** in project root
4. **Create supporting test scripts** in `scripts/`
5. **Set up pre-commit hook** (ask user if they want it)
6. **Document in STACK.md**:
   ```markdown
   ## Quality Validation
   - quality_checks: enabled
   - profile: juce_audio_plugin
   - pre_commit_hook: yes
   - run_command: bash quality_checks.sh --pre-commit
   - full_suite_command: bash quality_checks.sh --full
   ```
7. **Add to CI** (GitHub Actions example)

**Ask user**: "Should I set up automatic quality validation before commits?"
```

### 2. Retrospective Integration

**File**: `.agentic/workflows/retrospective.md`

Add section:

```markdown
### 8. Quality Validation Review (5-10 min)

**Check quality_checks.sh effectiveness:**
- Have any quality checks failed recently?
- Were bugs caught by checks or missed?
- Are checks too slow? (>2 min for pre-commit)
- Are checks too strict? (false positives)
- New failure modes discovered?

**Suggest improvements:**
- Add new checks for recent bug types
- Remove/relax checks causing false positives
- Optimize slow checks
- Update thresholds based on measurements

**Update quality_checks.sh if needed.**
```

### 3. STACK.md Template Update

**File**: `.agentic/init/STACK.template.md`

Add section:

```markdown
## Quality validation (recommended)
<!-- Automated, stack-specific quality gates run before commit -->
<!-- See: .agentic/workflows/continuous_quality_validation.md -->
- quality_checks: enabled
- profile: <!-- juce_audio_plugin | webapp_fullstack | ios_app | custom -->
- pre_commit_hook: yes  <!-- yes | no -->
- run_command: bash quality_checks.sh --pre-commit
- full_suite_command: bash quality_checks.sh --full
- ci_enabled: yes  <!-- Runs in GitHub Actions / CI -->

## Quality thresholds (stack-specific)
<!-- For JUCE plugins: -->
<!-- - max_cpu_percent: 50 -->
<!-- - max_latency_ms: 10 -->
<!-- - allow_nan_inf: no -->
<!-- - max_glitches: 0 -->

<!-- For web apps: -->
<!-- - max_bundle_size_kb: 500 -->
<!-- - min_lighthouse_performance: 90 -->
<!-- - min_lighthouse_accessibility: 95 -->

<!-- For mobile apps: -->
<!-- - max_memory_mb: 150 -->
<!-- - max_battery_per_hour_percent: 5 -->
<!-- - max_fps_drops: 5 -->
```

### 4. Pre-commit Hook Template

**File**: `.git/hooks/pre-commit` (generated by agent)

```bash
#!/usr/bin/env bash
# Auto-generated pre-commit hook for quality validation

echo "Running pre-commit quality checks..."
echo

bash quality_checks.sh --pre-commit

if [ $? -ne 0 ]; then
  echo
  echo "❌ Quality checks failed. Fix issues before committing."
  echo "   To skip (not recommended): git commit --no-verify"
  exit 1
fi

echo
echo "✅ Quality checks passed. Proceeding with commit."
```

### 5. CI Integration Template

**File**: `.github/workflows/quality-validation.yml`

```yaml
name: Quality Validation

on: [push, pull_request]

jobs:
  quality-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up environment
        run: |
          # Install dependencies based on STACK.md
          bash .agentic/tools/setup_ci.sh
      
      - name: Run full quality suite
        run: bash quality_checks.sh --full
        timeout-minutes: 30
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: quality-validation-results
          path: |
            validation_results/
            test_output/
            coverage/
```

## Quality Profile Library

**Location**: `.agentic/quality_profiles/`

- `juce_audio_plugin.sh` - JUCE plugin validation
- `raw_vst3_plugin.sh` - Raw VST3 SDK plugin validation (non-JUCE)
- `webapp_fullstack.sh` - Web app validation
- `ios_app.sh` - iOS app validation
- `android_app.sh` - Android app validation
- `python_ml.sh` - Python ML project validation
- `go_backend.sh` - Go backend service validation
- `rust_systems.sh` - Rust systems programming validation

Agents copy and customize these during init.

## Example: Agent Creates Quality Checks

**During init conversation:**

```
Agent: "I see you're building a JUCE audio plugin. Let me set up 
       comprehensive quality validation to catch audio-specific bugs:

       ✓ pluginval smoke & stress tests
       ✓ Offline DSP validation (no NaN/Inf)
       ✓ Realtime CPU & glitch detection
       ✓ Discontinuity & zipper noise detection
       ✓ Runaway feedback detection

       This will run automatically before each commit and in CI.
       
       Should I set this up? (yes/no)"

User: "yes"

Agent: [Creates quality_checks.sh with JUCE-specific tests]
       [Creates scripts/test_dsp_validation.py]
       [Creates scripts/test_realtime_performance.py]
       [Sets up pre-commit hook]
       [Updates STACK.md with thresholds]
       [Creates CI workflow]
       
       "✅ Quality validation set up! Run: bash quality_checks.sh"
```

## Benefits

✅ **Catch bugs early**: Before they reach production or even CI  
✅ **Stack-specific**: Tests match your technology's failure modes  
✅ **Automated**: No manual testing needed  
✅ **Fast feedback**: Fails in <2 min on commit  
✅ **Living standard**: Evolves with project in retrospectives  
✅ **CI-ready**: Same checks run locally and in CI  
✅ **Prevents regressions**: Tests encode lessons learned

## See Also

- Init playbook: `.agentic/init/init_playbook.md`
- Retrospective workflow: `.agentic/workflows/retrospective.md`
- Test strategy: `.agentic/quality/test_strategy.md`
- Stack profiles: `.agentic/support/stack_profiles/*.md`

