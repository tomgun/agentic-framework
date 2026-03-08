---
name: sandbox-setup
description: >
  Set up a Docker sandbox for autonomous Claude Code with configurable
  security. Interviews the user about permissions, generates devcontainer
  config, firewall rules, and GitHub token scoping.
  Use when: user says "setup sandbox", "configure docker", "sandbox setup",
  "devcontainer setup", "ag sandbox", or asks about running Claude in Docker.
  Do NOT use for: running commands inside an existing container, general
  Docker questions unrelated to Claude.
compatibility: "Requires Docker installed on the host."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, WebSearch]
metadata:
  author: agentic-framework
  version: "0.47.1"
---

# Sandbox Setup

Interactive setup wizard for running Claude Code autonomously in a Docker container with configurable security boundaries.

## Instructions

### Step 0: Read Reference Material

Read `references/sandbox_setup_guide.md` for the full interview script and decision trees. Follow it precisely.

### Step 1: Check Prerequisites

```bash
docker --version 2>/dev/null || echo "DOCKER_NOT_FOUND"
gh auth status 2>&1 || echo "GH_NOT_CONFIGURED"
```

If Docker is not installed, stop and tell the user to install Docker Desktop first.
If `gh` is not configured, note it — we'll handle auth setup in Step 4.

### Step 2: Detect Existing Setup

```bash
ls .devcontainer/ 2>/dev/null
cat .devcontainer/devcontainer.json 2>/dev/null
```

If a devcontainer already exists, offer to review/update it rather than overwriting.

### Step 3: Interview — Security Profile

Ask the user about their security preferences using the decision tree in the reference file. Present it as a simple choice first, then drill into details only if they pick "Custom".

### Step 4: Generate Configuration

Based on interview answers, generate:
1. `.devcontainer/Dockerfile`
2. `.devcontainer/devcontainer.json`
3. `.devcontainer/init-firewall.sh`
4. `.devcontainer/run.sh`
5. `.claude/settings.json` (if Tier 2 scoped mode chosen)

Use the templates and decision matrix from the reference file.

### Step 5: GitHub Token Setup

Guide the user through creating an appropriately scoped token based on their security profile choice.

### Step 6: Verify

Build and test the container:
```bash
bash .devcontainer/run.sh
# Inside: verify firewall, gh auth, claude version
```

## Examples

**Example 1: Quick setup, default security**
User: "set up the sandbox"
Steps: Check Docker → detect no existing setup → ask security profile → user picks "Standard" → generate all files with standard defaults → guide gh token → build and test.

**Example 2: Existing setup, wants to tighten**
User: "make the sandbox more restrictive"
Steps: Read existing devcontainer.json → show current config → interview about what to tighten → update firewall and/or settings.json.

## References

- For interview script and decision trees: see `references/sandbox_setup_guide.md`
- For full documentation: see `docs/SANDBOX.md`
