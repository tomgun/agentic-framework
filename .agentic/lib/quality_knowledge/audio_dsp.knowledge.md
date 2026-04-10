# Audio DSP Quality Knowledge

Deep domain expertise for building audio plugins (VST3, AU, AUv3) with JUCE, raw VST3 SDK, or iPlug2.

## Real-Time Safety Rules

The audio thread is the highest-priority thread in the system. processBlock (JUCE) / process (VST3) runs on this thread and must **never block**. Any operation that might block causes audio glitches — clicks, pops, dropouts — that are immediately audible to the user.

### Forbidden on the Audio Thread
- **Memory allocation** (`new`, `malloc`, `std::vector::push_back`): The OS memory allocator uses locks. Pre-allocate everything in `prepareToPlay`.
- **Mutex locks** (`std::mutex`, `juce::CriticalSection`): Use `juce::AbstractFifo` or lock-free ring buffers for thread communication.
- **File I/O** (`fopen`, `std::ifstream`): Load everything during initialization.
- **Console output** (`std::cout`, `printf`, `DBG`): Even logging can block. Use async logging if needed.
- **Objective-C message dispatch** (on macOS): ObjC runtime can lock. Keep all ObjC in the UI thread.
- **String operations** (`std::string` concatenation): Often allocates. Use fixed-size buffers.

### Safe Patterns
```cpp
// GOOD: Pre-allocated buffer
class MyProcessor : public AudioProcessor {
    std::vector<float> scratchBuffer;
    
    void prepareToPlay(double sampleRate, int maxBlockSize) override {
        scratchBuffer.resize(maxBlockSize);  // Allocate here
    }
    
    void processBlock(AudioBuffer<float>& buffer, MidiBuffer&) override {
        // Use pre-allocated buffer — no allocation here
        auto* scratch = scratchBuffer.data();
    }
};
```

```cpp
// GOOD: Lock-free parameter communication
std::atomic<float> paramValue{0.5f};

// UI thread writes:
paramValue.store(newValue, std::memory_order_relaxed);

// Audio thread reads:
float val = paramValue.load(std::memory_order_relaxed);
```

## Plugin Validation with pluginval

[pluginval](https://github.com/Tracktion/pluginval) is the industry-standard automated plugin validator by Tracktion. It tests host compatibility at increasing strictness levels (1-10).

### Strictness Levels
- **Level 1-3**: Basic loading, parameter enumeration, state save/restore
- **Level 4-5**: Bus layout changes, sample rate changes, random parameter automation
- **Level 6-7**: Rapid open/close, concurrent processing, edge case buffer sizes
- **Level 8-10**: Stress testing with random inputs, tiny buffers (1 sample), extreme sample rates

### Installation
```bash
# macOS (Homebrew Cask)
brew install --cask pluginval

# Linux — download from GitHub releases
wget https://github.com/Tracktion/pluginval/releases/latest/download/pluginval_Linux.zip

# Build from source (any platform)
git clone https://github.com/Tracktion/pluginval.git
cd pluginval && cmake -B build && cmake --build build
```

### Pre-Commit vs Full
- **Pre-commit** (strictness 3): Fast smoke test (~10 seconds). Catches crashes, basic parameter issues.
- **Full validation** (strictness 8): Thorough test (~2 minutes). Catches edge cases, threading issues, state corruption.

## Offline DSP Validation

Test your DSP algorithms with known inputs and expected outputs, independent of real-time constraints.

### What to Validate
1. **NaN/Inf detection**: Process silence, noise, and DC through the plugin. Check output for non-finite values.
2. **DC offset**: Process silence. Output should have DC offset < 0.01 (ideally < 0.001).
3. **Known input/output pairs**: Process a 440Hz sine wave. Compare output to expected reference (for gain plugins, EQs, etc.).
4. **Impulse response**: Send a single-sample impulse. Verify response matches expected filter shape.
5. **Bypass transparency**: When bypassed, output must exactly equal input (bit-perfect).

### Script Template
```python
#!/usr/bin/env python3
"""Offline DSP validation for audio plugins."""
import numpy as np
import subprocess
import sys

def validate_no_nan_inf(audio_data):
    """Check for NaN or Inf values."""
    if np.any(np.isnan(audio_data)):
        return False, "NaN values detected in output"
    if np.any(np.isinf(audio_data)):
        return False, "Inf values detected in output"
    return True, "No NaN/Inf"

def validate_dc_offset(audio_data, max_offset=0.01):
    """Check DC offset is within limits."""
    dc = np.mean(audio_data)
    if abs(dc) > max_offset:
        return False, f"DC offset {dc:.6f} exceeds limit {max_offset}"
    return True, f"DC offset {dc:.6f} OK"

def validate_output_matches(actual, expected, tolerance=0.001):
    """Compare output to expected reference."""
    diff = np.max(np.abs(actual - expected))
    if diff > tolerance:
        return False, f"Max difference {diff:.6f} exceeds tolerance {tolerance}"
    return True, f"Max difference {diff:.6f} OK"
```

## Real-Time Performance Testing

Measure processBlock CPU usage under realistic conditions.

### Key Metrics
- **CPU usage**: processBlock time / buffer duration. Target: <30% at 44.1kHz/128 samples.
- **Worst-case latency**: Maximum processBlock execution time across all buffers.
- **Glitch detection**: Any buffer where processing time exceeds buffer duration.
- **Jitter**: Standard deviation of processing times (indicates cache/branch prediction issues).

### Buffer Size / Sample Rate Matrix
Test at these combinations — each stresses different parts of the system:

| Sample Rate | Buffer 64 | Buffer 128 | Buffer 256 | Buffer 512 | Buffer 1024 |
|-------------|-----------|------------|------------|------------|-------------|
| 44100 Hz    | Stress    | Typical    | Relaxed    | -          | -           |
| 48000 Hz    | Stress    | Typical    | Relaxed    | -          | -           |
| 96000 Hz    | -         | Stress     | Typical    | Relaxed    | -           |
| 192000 Hz   | -         | -          | Stress     | Typical    | Relaxed     |

Small buffers at high sample rates = maximum CPU pressure.

## Common Anti-Patterns

### Zipper Noise
**Symptom**: Audible stepping/zippering when turning knobs.
**Cause**: Parameter values change discretely between buffers without smoothing.
**Fix**: Use `juce::SmoothedValue<float>` or implement exponential smoothing:
```cpp
// In processBlock:
float smoothed = previousValue + 0.001f * (targetValue - previousValue);
```
Rule of thumb: smoothing time of 10-50ms works for most controls.

### Denormal Numbers
**Symptom**: CPU spikes on silence or near-silence.
**Cause**: Floating-point denormals (very small numbers near zero) are 10-100x slower to process.
**Fix**: Add a tiny DC offset to feedback paths, or use `juce::ScopedNoDenormals` at the top of processBlock:
```cpp
void processBlock(AudioBuffer<float>& buffer, MidiBuffer&) override {
    juce::ScopedNoDenormals noDenormals;
    // ... processing ...
}
```

### State Save/Restore Drift
**Symptom**: Preset recall produces slightly different sound after reload.
**Cause**: Floating-point serialization loses precision, or internal state (filter memories) isn't saved.
**Fix**: Serialize parameters with full precision. Either save/restore filter states, or re-initialize filters from parameters on state restore.

### Click on Instantiation
**Symptom**: Audible click when plugin is first inserted.
**Cause**: Buffers not zero-initialized, or initial parameter state causes a step.
**Fix**: Zero all internal buffers in constructor/prepareToPlay. Ensure initial parameter values match what the DSP chain expects.

## Build System Notes

### JUCE Projects
```bash
# CMake (recommended)
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target MyPlugin_VST3

# Projucer (legacy)
# Open .jucer file, export to IDE, build from there
```

### Raw VST3 SDK Projects
```bash
# Must have VST3 SDK path set
cmake -B build -DCMAKE_BUILD_TYPE=Release -DVST3_SDK_ROOT=/path/to/vst3sdk
cmake --build build --config Release
```

### Output Locations
- **JUCE CMake**: `build/MyPlugin_artefacts/Release/VST3/MyPlugin.vst3`
- **JUCE Projucer**: `Builds/<IDE>/build/Release/MyPlugin.vst3`
- **Raw VST3**: `build/VST3/Release/MyPlugin.vst3` (varies by CMake config)

## Quick Test Hosts

For faster iteration than restarting a full DAW:
- **pluginval**: Automated validation, no GUI needed
- **REAPER**: Free to evaluate, ~2 second startup, excellent plugin compatibility
- **Carla** (Linux): Open-source plugin host with JACK support
- **AudioPluginHost** (JUCE): Included with JUCE, useful for debugging

## Manual Testing Checklist
- [ ] Load in DAW, verify no crash on insert
- [ ] Test at 44.1/48/96 kHz sample rates
- [ ] Test at 64/128/256/512/1024 buffer sizes
- [ ] Save and recall preset — verify identical sound
- [ ] Save DAW session, close, reopen — verify state restored
- [ ] Bypass and un-bypass — verify no click or level change
- [ ] Automate all parameters — verify smooth transitions
- [ ] Process silence for 60 seconds — verify no drift/noise
- [ ] Run at full CPU load (multiple instances) — verify graceful degradation
