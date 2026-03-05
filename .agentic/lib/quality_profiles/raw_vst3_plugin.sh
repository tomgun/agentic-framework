#!/usr/bin/env bash
# Raw VST3 SDK Plugin Quality Validation Profile
# For projects using Steinberg VST3 SDK directly (not JUCE/iPlug2)
# Auto-generated - customize thresholds as needed

set -euo pipefail

MODE="${1:---pre-commit}"  # --pre-commit or --full

echo "=== Raw VST3 Plugin Quality Validation ==="
echo "Mode: ${MODE}"
echo

# Configuration (update these thresholds as needed)
MAX_CPU_PERCENT=50
STRICTNESS=5
TEST_DURATION=60  # seconds for full test, 10 for pre-commit

if [ "${MODE}" == "--pre-commit" ]; then
  STRICTNESS=3  # Faster for pre-commit
  TEST_DURATION=10
fi

# Create validation results directory
mkdir -p validation_results

# 1. Build check
echo "1. Build validation..."
if [ ! -d "build" ]; then
  echo "   Creating build directory..."
  cmake -B build -DCMAKE_BUILD_TYPE=Release
fi

cmake --build build --config Release -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) 2>&1 | tail -n 20
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi
echo "✅ Build successful"
echo

# 2. Find plugin binary
# Raw VST3 SDK typically outputs to build/VST3/Release/ or build/VST3/Debug/
PLUGIN_PATH=$(find build -name "*.vst3" -type d 2>/dev/null | head -n 1)
if [ -z "${PLUGIN_PATH}" ]; then
  echo "❌ No .vst3 bundle found in build/"
  echo "   Expected: build/VST3/Release/YourPlugin.vst3"
  exit 1
fi
echo "   Found plugin: ${PLUGIN_PATH}"
echo

# 3. Pluginval validation
echo "2. Running pluginval validation..."

# Find pluginval - check multiple locations:
# - In PATH (Linux, manual install)
# - Homebrew Cask on Apple Silicon: /opt/homebrew/Caskroom/pluginval/*/pluginval.app
# - Homebrew Cask on Intel Mac: /usr/local/Caskroom/pluginval/*/pluginval.app
# - Applications folder: /Applications/pluginval.app
PLUGINVAL=""
if command -v pluginval &> /dev/null; then
  PLUGINVAL="pluginval"
elif [ -d "/opt/homebrew/Caskroom/pluginval" ]; then
  # Apple Silicon Homebrew Cask
  PLUGINVAL=$(find /opt/homebrew/Caskroom/pluginval -name "pluginval" -path "*/MacOS/*" 2>/dev/null | head -n 1)
elif [ -d "/usr/local/Caskroom/pluginval" ]; then
  # Intel Mac Homebrew Cask
  PLUGINVAL=$(find /usr/local/Caskroom/pluginval -name "pluginval" -path "*/MacOS/*" 2>/dev/null | head -n 1)
elif [ -x "/Applications/pluginval.app/Contents/MacOS/pluginval" ]; then
  PLUGINVAL="/Applications/pluginval.app/Contents/MacOS/pluginval"
fi

if [ -n "${PLUGINVAL}" ]; then
  echo "   Using: ${PLUGINVAL}"
  # Note: --validate must be immediately followed by the plugin path
  "${PLUGINVAL}" --validate "$(pwd)/${PLUGIN_PATH}" \
    --strictness-level ${STRICTNESS} \
    --validate-in-process \
    --timeout-ms 60000 \
    2>&1 | tee validation_results/pluginval.log

  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ Pluginval failed. See validation_results/pluginval.log"
    exit 1
  fi
  echo "✅ Pluginval passed (strictness level ${STRICTNESS})"
else
  echo "⚠️  pluginval not found."
  echo "   Install options:"
  echo "     macOS: brew install --cask pluginval"
  echo "     Linux: Download from https://github.com/Tracktion/pluginval/releases"
  echo "     Or build from source: https://github.com/Tracktion/pluginval"
  if [ "${MODE}" == "--full" ]; then
    exit 1  # Fail on full validation if pluginval missing
  fi
fi
echo

# 4. Unit tests (project-specific)
echo "3. Running unit tests..."
# Common locations for test executables in CMake projects
TEST_EXECUTABLE=""
for path in "build/tests/Tests" "build/test/Tests" "build/bin/Tests"; do
  if [ -x "${path}" ]; then
    TEST_EXECUTABLE="${path}"
    break
  fi
done

if [ -n "${TEST_EXECUTABLE}" ]; then
  "${TEST_EXECUTABLE}"
  if [ $? -ne 0 ]; then
    echo "❌ Unit tests failed"
    exit 1
  fi
  echo "✅ Unit tests passed"
else
  echo "⚠️  Unit tests not found"
  echo "   Expected locations: build/tests/Tests, build/bin/Tests"
fi
echo

# 5. Offline DSP validation (if script exists)
if [ -f "scripts/test_dsp_validation.py" ]; then
  echo "4. Running offline DSP validation..."
  python3 scripts/test_dsp_validation.py \
    --plugin "$(pwd)/${PLUGIN_PATH}" \
    --check-nan-inf \
    --check-dc-offset \
    --max-dc-offset 0.01

  if [ $? -ne 0 ]; then
    echo "❌ DSP validation failed"
    exit 1
  fi
  echo "✅ DSP validation passed"
else
  echo "4. ⚠️  scripts/test_dsp_validation.py not found."
  echo "   Create this script to validate:"
  echo "   - No NaN/Inf values in output"
  echo "   - DC offset within limits"
  echo "   - Expected output for known inputs"
fi
echo

# 6. Realtime performance test (if script exists)
if [ -f "scripts/test_realtime_performance.py" ] && [ "${MODE}" == "--full" ]; then
  echo "5. Running realtime CPU & glitch detection..."
  python3 scripts/test_realtime_performance.py \
    --plugin "$(pwd)/${PLUGIN_PATH}" \
    --duration ${TEST_DURATION} \
    --max-cpu-percent ${MAX_CPU_PERCENT} \
    --detect-glitches \
    --detect-nan-inf

  if [ $? -ne 0 ]; then
    echo "❌ Performance validation failed"
    exit 1
  fi
  echo "✅ Performance validation passed"
else
  if [ "${MODE}" == "--full" ]; then
    echo "5. ⚠️  scripts/test_realtime_performance.py not found."
    echo "   Create this script to measure:"
    echo "   - processBlock() CPU usage"
    echo "   - Glitch detection (processing > buffer time)"
    echo "   - NaN/Inf detection during processing"
  fi
fi
echo

# 7. Summary
echo "=========================================="
echo "✅ Quality validation complete!"
echo
echo "Quality checks performed:"
echo "  ✓ Build validation (CMake)"
if [ -n "${PLUGINVAL:-}" ]; then
  echo "  ✓ Pluginval (strictness ${STRICTNESS})"
fi
if [ -n "${TEST_EXECUTABLE:-}" ]; then
  echo "  ✓ Unit tests"
fi
if [ -f "scripts/test_dsp_validation.py" ]; then
  echo "  ✓ DSP validation"
fi
if [ -f "scripts/test_realtime_performance.py" ] && [ "${MODE}" == "--full" ]; then
  echo "  ✓ Realtime performance"
fi
echo
echo "Manual testing recommended:"
echo "  - Load in DAW and verify functionality"
echo "  - Test with various sample rates and buffer sizes"
echo "  - Monitor CPU usage during playback"
echo
echo "Quick test hosts (faster than full DAW restart):"
echo "  - pluginval: Automated validation"
echo "  - REAPER: Fast startup (~2s), free to evaluate"
echo
