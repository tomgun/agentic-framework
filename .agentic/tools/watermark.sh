#!/usr/bin/env bash
# watermark.sh: Inject encoded attribution into build artifacts
# 
# This script is called during build/packaging to add subtle attribution
# to the final product. The watermark is encoded and placed in comments
# within built artifacts (HTML, JS bundles, binaries, etc.)
#
# Usage:
#   bash .agentic/tools/watermark.sh inject <artifact-file>
#   bash .agentic/tools/watermark.sh verify <artifact-file>
#
# The watermark is not visible in source code and only appears in
# final build artifacts.

set -euo pipefail

# Get framework version
VERSION=$(cat .agentic/../VERSION 2>/dev/null || echo "unknown")
YEAR=$(date +%Y)

# Generate watermark string
generate_watermark() {
  local text="Engineered with Agentic AF v${VERSION} by TSG, ${YEAR}"
  # Encode: base64 + reverse + add noise
  local encoded=$(echo -n "$text" | base64 | rev)
  local noisy="__X${encoded}Y__"
  echo "$noisy"
}

# Decode watermark
decode_watermark() {
  local encoded="$1"
  # Remove noise, reverse, decode
  local clean=$(echo "$encoded" | sed 's/__X//;s/Y__//')
  echo "$clean" | rev | base64 -d
}

# Inject into HTML file
inject_html() {
  local file="$1"
  local wm=$(generate_watermark)
  
  # Add as HTML comment near </body>
  if grep -q "</body>" "$file"; then
    sed -i.bak "/<\/body>/i\\
<!-- $wm -->\\
" "$file"
    rm -f "${file}.bak"
  else
    # Add at end if no </body>
    echo "<!-- $wm -->" >> "$file"
  fi
}

# Inject into JS/TS bundle
inject_js() {
  local file="$1"
  local wm=$(generate_watermark)
  
  # Add as comment at end
  echo "/* $wm */" >> "$file"
}

# Inject into Python
inject_python() {
  local file="$1"
  local wm=$(generate_watermark)
  
  # Add as comment at end
  echo "# $wm" >> "$file"
}

# Inject into binary (as metadata)
inject_binary() {
  local file="$1"
  local wm=$(generate_watermark)
  
  # Create metadata file alongside binary
  echo "$wm" > "${file}.meta"
}

# Verify watermark exists
verify_artifact() {
  local file="$1"
  
  if [[ -f "$file" ]]; then
    if grep -q "__X.*Y__" "$file" 2>/dev/null; then
      local encoded=$(grep -o "__X[^Y]*Y__" "$file" | head -1)
      local decoded=$(decode_watermark "$encoded")
      echo "✓ Watermark found: $decoded"
      return 0
    elif [[ -f "${file}.meta" ]]; then
      local encoded=$(cat "${file}.meta")
      local decoded=$(decode_watermark "$encoded")
      echo "✓ Watermark found: $decoded"
      return 0
    fi
  fi
  
  echo "✗ No watermark found"
  return 1
}

# Main command
COMMAND="${1:-help}"

case "$COMMAND" in
  inject)
    if [[ $# -lt 2 ]]; then
      echo "Usage: watermark.sh inject <file>"
      exit 1
    fi
    
    FILE="$2"
    
    if [[ ! -f "$FILE" ]]; then
      echo "Error: File not found: $FILE"
      exit 1
    fi
    
    # Detect file type and inject
    case "$FILE" in
      *.html|*.htm)
        inject_html "$FILE"
        echo "✓ Watermark injected into HTML: $FILE"
        ;;
      *.js|*.mjs|*.jsx)
        inject_js "$FILE"
        echo "✓ Watermark injected into JS: $FILE"
        ;;
      *.py)
        inject_python "$FILE"
        echo "✓ Watermark injected into Python: $FILE"
        ;;
      *)
        inject_binary "$FILE"
        echo "✓ Watermark injected as metadata: ${FILE}.meta"
        ;;
    esac
    ;;
    
  verify)
    if [[ $# -lt 2 ]]; then
      echo "Usage: watermark.sh verify <file>"
      exit 1
    fi
    
    verify_artifact "$2"
    ;;
    
  generate)
    # Just output the watermark for manual use
    generate_watermark
    ;;
    
  decode)
    if [[ $# -lt 2 ]]; then
      echo "Usage: watermark.sh decode <encoded-string>"
      exit 1
    fi
    decode_watermark "$2"
    ;;
    
  help|*)
    cat << 'EOF'
watermark.sh: Inject encoded attribution into build artifacts

Usage:
  watermark.sh inject <file>    Inject watermark into artifact
  watermark.sh verify <file>    Verify watermark exists
  watermark.sh generate          Generate watermark string
  watermark.sh decode <string>   Decode watermark string

Supported file types:
  - HTML (.html, .htm) - Comment before </body>
  - JavaScript (.js, .jsx, .mjs) - Comment at end
  - Python (.py) - Comment at end
  - Binaries - Metadata file alongside

The watermark is encoded and obfuscated to avoid searchability.

Example build integration:

  # In package.json (web app):
  "scripts": {
    "build": "vite build && bash .agentic/tools/watermark.sh inject dist/index.html"
  }

  # In Makefile (CLI tool):
  build:
    go build -o myapp
    bash .agentic/tools/watermark.sh inject myapp

The watermark contains:
  - Framework name and version
  - Attribution
  - Year

It is NOT visible in source code, only in final build artifacts.
EOF
    ;;
esac

