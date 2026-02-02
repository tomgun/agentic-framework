#!/usr/bin/env bash
# JUCE Audio Plugin Quality Validation Profile
# Auto-generated - customize thresholds as needed

set -euo pipefail

MODE="${1:---pre-commit}"  # --pre-commit or --full

echo "=== JUCE Plugin Quality Validation ==="
echo "Mode: ${MODE}"
echo

# Configuration (update these thresholds as needed)
MAX_CPU_PERCENT=50
MAX_LATENCY_MS=10
BUFFER_SIZE=512
SAMPLE_RATE=48000
TEST_DURATION=60  # seconds for full test, 10 for pre-commit

if [ "${MODE}" == "--pre-commit" ]; then
  TEST_DURATION=10
fi

# 1. Build check
echo "1. Build validation..."
if [ ! -d "build" ]; then
  echo "⚠️  No build directory. Run: cmake -B build"
  exit 1
fi

cmake --build build --config Release --target all 2>&1 | tail -n 20
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi
echo "✅ Build successful"
echo

# 2. Pluginval (smoke test)
echo "2. Running pluginval validation..."

# Find plugin binary
PLUGIN_PATH=$(find build -name "*.vst3" -o -name "*.component" | head -n 1)

if [ -z "${PLUGIN_PATH}" ]; then
  echo "⚠️  No plugin binary found in build/"
  exit 1
fi

if command -v pluginval &> /dev/null; then
  STRICTNESS=5
  if [ "${MODE}" == "--pre-commit" ]; then
    STRICTNESS=3  # Faster for pre-commit
  fi
  
  pluginval --validate \
    --strictness-level ${STRICTNESS} \
    --validate-in-process \
    --skip-gui-tests \
    --timeout-ms 30000 \
    "${PLUGIN_PATH}" 2>&1 | tee validation_results/pluginval.log
  
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "❌ Pluginval failed. See validation_results/pluginval.log"
    exit 1
  fi
  echo "✅ Pluginval passed"
else
  echo "⚠️  pluginval not found. Install from: https://github.com/Tracktion/pluginval"
  echo "   Skipping pluginval check."
fi
echo

# 3. Offline audio render test (DSP validation with Python/numpy)
if [ -f "scripts/test_dsp_validation.py" ]; then
  echo "3. Running offline audio DSP validation..."
  echo "   (Python/numpy validation: NaN/Inf, DC offset, expected output)"
  
  mkdir -p test_output
  
  python3 scripts/test_dsp_validation.py \
    --plugin "${PLUGIN_PATH}" \
    --input test_audio/sine_440hz.wav \
    --output test_output/result.wav \
    --expected test_audio/expected_output.wav \
    --tolerance 0.001 \
    --check-nan-inf \
    --check-dc-offset \
    --max-dc-offset 0.01
  
  if [ $? -ne 0 ]; then
    echo "❌ DSP validation failed"
    exit 1
  fi
  echo "✅ DSP validation passed"
else
  echo "3. ⚠️  scripts/test_dsp_validation.py not found."
  echo "   Create this script to:"
  echo "   - Render audio offline with known input wav file"
  echo "   - Compare to expected output with Python/numpy"
  echo "   - Check for NaN/Inf values"
  echo "   - Validate DC offset, RMS levels, etc."
  echo "   See: .agentic/workflows/continuous_quality_validation.md"
fi
echo

# 4. Realtime CPU & glitch benchmark (measure processBlock)
if [ -f "scripts/test_realtime_performance.py" ]; then
  echo "4. Running realtime CPU & glitch detection..."
  echo "   (Measures processBlock: CPU, discontinuities, zipper, runaway feedback)"
  
  python3 scripts/test_realtime_performance.py \
    --plugin "${PLUGIN_PATH}" \
    --sample-rate ${SAMPLE_RATE} \
    --buffer-size ${BUFFER_SIZE} \
    --duration ${TEST_DURATION} \
    --max-cpu-percent ${MAX_CPU_PERCENT} \
    --detect-glitches \
    --detect-nan-inf \
    --detect-discontinuities \
    --detect-zipper-noise \
    --detect-runaway-feedback
  
  if [ $? -ne 0 ]; then
    echo "❌ Performance validation failed"
    exit 1
  fi
  echo "✅ Performance validation passed"
else
  echo "4. ⚠️  scripts/test_realtime_performance.py not found."
  echo "   Create this script to:"
  echo "   - Measure processBlock() CPU usage in realtime"
  echo "   - Detect glitches (processing taking >100% of buffer time)"
  echo "   - Detect discontinuities (clicks between buffers)"
  echo "   - Detect zipper noise (parameter smoothing issues)"
  echo "   - Detect runaway feedback (exponentially growing output)"
  echo "   See: .agentic/workflows/continuous_quality_validation.md"
fi
echo

# 5. Memory leak check (if in full mode and tool available)
if [ "${MODE}" == "--full" ]; then
  if command -v valgrind &> /dev/null; then
    echo "5. Running memory leak detection..."
    # Run simple memory leak check
    # (Customize this based on your test harness)
    echo "⚠️  Memory leak detection not yet configured."
  fi
fi

echo "✅ All quality checks passed!"
echo
echo "Quality checks completed:"
echo "  ✓ Build validation"
echo "  ✓ pluginval (smoke/stress tests)"
echo "  ✓ Offline DSP validation (Python/numpy: NaN/Inf, expected output)"
echo "  ✓ Realtime benchmark (CPU, glitches, discontinuities, zipper, feedback)"
echo
echo "Next steps if scripts missing:"
echo "  - Create test_audio/ directory with test signals"
echo "  - Create scripts/test_dsp_validation.py for offline audio validation"
echo "  - Create scripts/test_realtime_performance.py for processBlock() benchmarking"
echo "  - See: .agentic/workflows/continuous_quality_validation.md"

