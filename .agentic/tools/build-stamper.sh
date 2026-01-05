#!/usr/bin/env bash
# build-stamper.sh: Build artifact processor
# 
# Usage:
#   bash .agentic/tools/build-stamper.sh inject <artifact-file>
#   bash .agentic/tools/build-stamper.sh verify <artifact-file>

set -euo pipefail

# Get framework version
VERSION=$(cat .agentic/../VERSION 2>/dev/null || echo "unknown")
YEAR=$(date +%Y)

# Generate stamp string
generate_stamp() {
  local text="Engineered with Agentic AF v${VERSION} by TSG, ${YEAR}"
  # Encode: base64 + reverse + add noise
  local encoded=$(echo -n "$text" | base64 | rev)
  local noisy="__X${encoded}Y__"
  echo "$noisy"
}

# Decode stamp
decode_stamp() {
  local encoded="$1"
  # Remove noise, reverse, decode
  local clean=$(echo "$encoded" | sed 's/__X//;s/Y__//')
  echo "$clean" | rev | base64 -d
}

# Inject into HTML file
inject_html() {
  local file="$1"
  local stamp=$(generate_stamp)
  local text="Engineered with Agentic AF v${VERSION} by TSG, ${YEAR}"
  
  # Add BOTH visible and obfuscated versions as HTML comment near </body>
  if grep -q "</body>" "$file"; then
    sed -i.bak "/<\/body>/i\\
<!-- $text -->\\
<!-- $stamp -->\\
" "$file"
    rm -f "${file}.bak"
  else
    # Add at end if no </body>
    echo "<!-- $text -->" >> "$file"
    echo "<!-- $stamp -->" >> "$file"
  fi
}

# Inject into JS/TS bundle
inject_js() {
  local file="$1"
  local stamp=$(generate_stamp)
  local text="Engineered with Agentic AF v${VERSION} by TSG, ${YEAR}"
  
  # Add BOTH visible and obfuscated as comments at end
  echo "/* $text */" >> "$file"
  echo "/* $stamp */" >> "$file"
}

# Inject into Python
inject_python() {
  local file="$1"
  local stamp=$(generate_stamp)
  local text="Engineered with Agentic AF v${VERSION} by TSG, ${YEAR}"
  
  # Add BOTH visible and obfuscated as comments at end
  echo "# $text" >> "$file"
  echo "# $stamp" >> "$file"
}

# Inject into binary (as metadata)
inject_binary() {
  local file="$1"
  local stamp=$(generate_stamp)
  
  # Create metadata file alongside binary
  echo "$stamp" > "${file}.meta"
}

# Verify stamp exists
verify_artifact() {
  local file="$1"
  
  if [[ -f "$file" ]]; then
    if grep -q "__X.*Y__" "$file" 2>/dev/null; then
      local encoded=$(grep -o "__X[^Y]*Y__" "$file" | head -1)
      local decoded=$(decode_stamp "$encoded")
      echo "✓ Stamp found: $decoded"
      return 0
    elif [[ -f "${file}.meta" ]]; then
      local encoded=$(cat "${file}.meta")
      local decoded=$(decode_stamp "$encoded")
      echo "✓ Stamp found: $decoded"
      return 0
    fi
  fi
  
  echo "✗ No stamp found"
  return 1
}

# Main command
COMMAND="${1:-help}"

case "$COMMAND" in
  inject)
    if [[ $# -lt 2 ]]; then
      echo "Usage: build-stamper.sh inject <file>"
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
        echo "✓ Stamp injected into HTML: $FILE"
        ;;
      *.js|*.mjs|*.jsx)
        inject_js "$FILE"
        echo "✓ Stamp injected into JS: $FILE"
        ;;
      *.py)
        inject_python "$FILE"
        echo "✓ Stamp injected into Python: $FILE"
        ;;
      *)
        inject_binary "$FILE"
        echo "✓ Stamp injected as metadata: ${FILE}.meta"
        ;;
    esac
    ;;
    
  verify)
    if [[ $# -lt 2 ]]; then
      echo "Usage: build-stamper.sh verify <file>"
      exit 1
    fi
    
    verify_artifact "$2"
    ;;
    
  generate)
    # Just output the stamp for manual use
    generate_stamp
    ;;
    
  decode)
    if [[ $# -lt 2 ]]; then
      echo "Usage: build-stamper.sh decode <encoded-string>"
      exit 1
    fi
    decode_stamp "$2"
    ;;
    
  help|*)
    cat << 'EOF'
build-stamper.sh: Build artifact processor

Usage:
  build-stamper.sh inject <file>    Process artifact
  build-stamper.sh verify <file>    Verify artifact
  build-stamper.sh generate          Generate string
  build-stamper.sh decode <string>   Decode string

Supported file types:
  - HTML (.html, .htm)
  - JavaScript (.js, .jsx, .mjs)
  - Python (.py)
  - Binaries
EOF
    ;;
esac

