#!/usr/bin/env bash
# Game Unity Quality Profile
# Purpose: Validate Unity game quality before commits
set -euo pipefail

echo "=== Unity Game Quality Checks ==="

ERRORS=0

# 1. Check Unity project structure
if [[ ! -d "Assets/" ]] || [[ ! -d "ProjectSettings/" ]]; then
  echo "❌ Not a Unity project (missing Assets/ or ProjectSettings/)"
  exit 1
fi

echo "✅ Unity project detected"

# 2. C# Linting (if available)
echo "📋 Checking for C# linting..."
if command -v dotnet >/dev/null 2>&1; then
  if [[ -f "*.sln" ]]; then
    echo "  Running dotnet format..."
    if dotnet format --verify-no-changes 2>/dev/null; then
      echo "  ✅ Code formatting valid"
    else
      echo "  ⚠️  Code formatting issues detected"
      echo "     Run: dotnet format"
    fi
  fi
else
  echo "  ℹ️  dotnet CLI not available (optional)"
fi

# 3. Unity Tests (EditMode and PlayMode)
echo "🧪 Checking for Unity tests..."
if [[ -d "Assets/Tests/" ]] || find Assets/ -name "*Tests" -type d 2>/dev/null | head -1 > /dev/null; then
  echo "  ✅ Test directories found"
  echo "     Run tests in Unity: Window > General > Test Runner"
else
  echo "  ⚠️  No test directories found"
  echo "     Create tests: Assets/Tests/ for EditMode and PlayMode tests"
fi

# 4. Scene Validation
echo "🎬 Checking scenes..."
SCENE_COUNT=$(find Assets/ -name "*.unity" 2>/dev/null | wc -l)
if [[ "$SCENE_COUNT" -eq 0 ]]; then
  echo "  ⚠️  WARNING: No scenes found"
else
  echo "  ✅ Found $SCENE_COUNT scene(s)"
fi

# 5. Performance Checks

# Check for missing prefab references (common Unity issue)
echo "🔗 Checking for common Unity anti-patterns..."
if grep -r "Missing (Script)\|Missing Prefab" Assets/ 2>/dev/null > /dev/null; then
  echo "  ❌ Missing script or prefab references detected!"
  echo "     Fix in Unity Editor"
  ((ERRORS++))
else
  echo "  ✅ No missing references detected"
fi

# Check for Update() usage without Time.deltaTime
echo "⏱️  Checking frame rate independence..."
if grep -r "void Update()" Assets/ 2>/dev/null | wc -l | grep -v "^0$" > /dev/null; then
  DELTA_TIME_USAGE=$(grep -r "Time\.deltaTime" Assets/ 2>/dev/null | wc -l || echo "0")
  UPDATE_USAGE=$(grep -r "void Update()" Assets/ 2>/dev/null | wc -l || echo "1")
  
  if [[ "$DELTA_TIME_USAGE" -lt "$((UPDATE_USAGE / 2))" ]]; then
    echo "  ⚠️  WARNING: Update() methods found but limited Time.deltaTime usage"
    echo "     Ensure movement/animations use Time.deltaTime for frame independence"
  else
    echo "  ✅ Good Time.deltaTime usage"
  fi
fi

# Check for GameObject.Find (performance killer)
echo "🔍 Checking for GameObject.Find usage..."
FIND_USAGE=$(grep -r "GameObject\.Find\|Find<" Assets/ 2>/dev/null | grep -v "//.*GameObject\.Find" | wc -l || echo "0")
if [[ "$FIND_USAGE" -gt 5 ]]; then
  echo "  ⚠️  WARNING: $FIND_USAGE GameObject.Find() calls detected"
  echo "     This is expensive! Use [SerializeField] or caching instead"
  echo "     See: .agentic/workflows/game_development.md#performance"
else
  echo "  ✅ Limited GameObject.Find usage"
fi

# Check for GetComponent in Update (also expensive)
echo "⚡ Checking for GetComponent in Update..."
if grep -r "void Update" Assets/ 2>/dev/null | xargs grep -l "GetComponent" 2>/dev/null | head -1 > /dev/null; then
  echo "  ⚠️  WARNING: GetComponent() calls might be in Update()"
  echo "     Cache component references in Start() or Awake()"
else
  echo "  ✅ No obvious GetComponent in Update"
fi

# 6. Asset Size Check
echo "📦 Checking asset sizes..."
if [[ -d "Assets/" ]]; then
  LARGE_ASSETS=$(find Assets/ -size +10M 2>/dev/null | grep -v "\.meta$" || true)
  if [[ -n "$LARGE_ASSETS" ]]; then
    echo "  ⚠️  WARNING: Very large assets detected (>10MB)"
    echo "$LARGE_ASSETS"
    echo "     Consider compression or optimization"
  else
    echo "  ✅ Asset sizes reasonable"
  fi
fi

# 7. Determinism Check (for replay/testing)
echo "🎲 Checking for determinism considerations..."
if grep -r "Random\.Range\|UnityEngine\.Random" Assets/ 2>/dev/null | wc -l | grep -v "^0$" > /dev/null; then
  SEED_USAGE=$(grep -r "Random\.InitState" Assets/ 2>/dev/null | wc -l || echo "0")
  if [[ "$SEED_USAGE" -eq 0 ]]; then
    echo "  ℹ️  Random usage found but no seed initialization"
    echo "     For deterministic testing, use Random.InitState(seed)"
    echo "     See: .agentic/workflows/game_development.md#determinism"
  else
    echo "  ✅ Deterministic random usage detected"
  fi
fi

# 8. Build Settings Check
echo "🏗️  Checking build settings..."
if [[ -f "ProjectSettings/ProjectSettings.asset" ]]; then
  echo "  ✅ ProjectSettings.asset found"
else
  echo "  ⚠️  ProjectSettings.asset missing?"
fi

echo ""
echo "==================================="
if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All critical checks passed!"
  echo ""
  echo "Additional Unity-specific checks to run manually:"
  echo "  1. Window > General > Test Runner (run all tests)"
  echo "  2. Window > Analysis > Profiler (check for performance spikes)"
  echo "  3. Build project and test on target platform"
  echo "  4. Check console for warnings/errors"
  exit 0
else
  echo "❌ $ERRORS critical check(s) failed"
  exit 1
fi

