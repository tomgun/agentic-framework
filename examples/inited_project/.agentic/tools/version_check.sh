#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"
STACK_FILE="${ROOT_DIR}/STACK.md"

echo "=== Version Check ==="
echo

if [[ ! -f "${STACK_FILE}" ]]; then
  echo "ERROR: STACK.md not found."
  exit 1
fi

# Extract versions from STACK.md
echo "Declared versions in STACK.md:"
echo

# This is a simplified version - would need to be enhanced per project type
# to parse package.json, requirements.txt, go.mod, etc.

# Check if package.json exists (Node.js project)
if [[ -f "${ROOT_DIR}/package.json" ]]; then
  echo "--- Node.js Dependencies ---"
  
  # Check major frameworks declared in STACK.md
  for framework in "next" "react" "vue" "svelte" "express" "fastify"; do
    STACK_VERSION=$(grep -i "${framework}" "${STACK_FILE}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1 || echo "")
    if [[ -n "${STACK_VERSION}" ]]; then
      # Check in package.json
      PACKAGE_VERSION=$(grep "\"${framework}\"" "${ROOT_DIR}/package.json" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "not found")
      
      if [[ "${PACKAGE_VERSION}" == "not found" ]]; then
        echo "⚠️  ${framework}: Declared in STACK.md (${STACK_VERSION}) but not in package.json"
      elif [[ "${PACKAGE_VERSION}" == "${STACK_VERSION}"* ]]; then
        echo "✅ ${framework}: ${PACKAGE_VERSION} (matches STACK.md ${STACK_VERSION})"
      else
        echo "❌ ${framework}: ${PACKAGE_VERSION} in package.json, STACK.md declares ${STACK_VERSION}"
      fi
    fi
  done
fi

# Check if requirements.txt exists (Python project)
if [[ -f "${ROOT_DIR}/requirements.txt" ]]; then
  echo
  echo "--- Python Dependencies ---"
  
  for framework in "django" "fastapi" "flask" "pytest"; do
    STACK_VERSION=$(grep -i "${framework}" "${STACK_FILE}" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1 || echo "")
    if [[ -n "${STACK_VERSION}" ]]; then
      REQUIREMENTS_VERSION=$(grep -i "^${framework}==" "${ROOT_DIR}/requirements.txt" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "not found")
      
      if [[ "${REQUIREMENTS_VERSION}" == "not found" ]]; then
        echo "⚠️  ${framework}: Declared in STACK.md (${STACK_VERSION}) but not in requirements.txt"
      elif [[ "${REQUIREMENTS_VERSION}" == "${STACK_VERSION}"* ]]; then
        echo "✅ ${framework}: ${REQUIREMENTS_VERSION} (matches STACK.md ${STACK_VERSION})"
      else
        echo "❌ ${framework}: ${REQUIREMENTS_VERSION} in requirements.txt, STACK.md declares ${STACK_VERSION}"
      fi
    fi
  done
fi

echo
echo "💡 Tip: Keep STACK.md versions synchronized with dependency files."
echo "   Run after: npm install, pip install, go get, etc."
echo
echo "   See: .agentic/workflows/documentation_verification.md"

