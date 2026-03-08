#!/bin/bash
# Run Claude Code in a sandboxed Docker container with no permission prompts.
# Usage: bash .devcontainer/run.sh [optional claude args]
#   bash .devcontainer/run.sh                          # interactive shell
#   bash .devcontainer/run.sh -p "fix the tests"       # one-shot task

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Extract GitHub token from host keychain (gh stores tokens in macOS Keychain,
# which isn't available inside Linux containers)
GH_TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null)}"

# Build the image if needed
docker build -t claude-sandbox "$SCRIPT_DIR"

# Run with host auth mounted in
if [ $# -eq 0 ]; then
  # Interactive: drop into shell, user runs claude manually
  docker run -it --rm \
    --cap-add=NET_ADMIN --cap-add=NET_RAW \
    -v "$HOME/.claude:/home/node/.claude" \
    -v "$HOME/.ssh:/home/node/.ssh:ro" \
    -v "claude-sandbox-history:/commandhistory" \
    -e "GH_TOKEN=$GH_TOKEN" \
    -v "$PROJECT_DIR:/workspace" \
    claude-sandbox zsh
else
  # One-shot: pass args directly to claude
  docker run -it --rm \
    --cap-add=NET_ADMIN --cap-add=NET_RAW \
    -v "$HOME/.claude:/home/node/.claude" \
    -v "$HOME/.ssh:/home/node/.ssh:ro" \
    -v "claude-sandbox-history:/commandhistory" \
    -e "GH_TOKEN=$GH_TOKEN" \
    -v "$PROJECT_DIR:/workspace" \
    claude-sandbox claude --dangerously-skip-permissions "$@"
fi
