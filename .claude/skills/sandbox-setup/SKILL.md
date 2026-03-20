---
name: sandbox-setup
description: >
  Set up a Docker sandbox for autonomous Claude Code with configurable
  security. Interviews the user about permissions, generates devcontainer
  config, firewall rules, and GitHub token scoping.
  Use when the user wants to set up a sandboxed environment for Claude —
  e.g. "setup sandbox", "configure docker", "sandbox setup", "devcontainer
  setup", "ag sandbox", "container setup", or asks about running Claude in
  Docker. Match intent, not exact words.
  Do NOT use for: running commands inside an existing container, general
  Docker questions unrelated to Claude.
compatibility: "Requires Docker installed on the host."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, WebSearch]
metadata:
  author: agentic-framework
  version: "0.47.1"
---
# Sandbox Setup

Interactive setup wizard for Docker-based Claude Code sandbox.

Steps:
1. Check prerequisites: `docker --version`, `gh auth status`
2. Detect existing `.devcontainer/` setup
3. Interview user about security profile (Standard / Restricted / Custom)
4. Generate: Dockerfile, devcontainer.json, init-firewall.sh, run.sh
5. Guide GitHub token scoping
6. Build and verify: `bash .devcontainer/run.sh`

See `docs/SANDBOX.md` for full documentation.
