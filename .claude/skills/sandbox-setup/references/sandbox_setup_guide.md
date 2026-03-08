# Sandbox Setup Guide

LLM-optimized instructions for setting up a Docker sandbox and interviewing the user about permissions.

## Interview Script

### Question 1: Security Profile (ask this first)

Present these three profiles. Default to Standard if the user is unsure.

```
How locked down should the sandbox be?

1. **Open** — Full autonomy. Claude can do anything inside the container.
   Network: all HTTPS/HTTP open, core services allowlisted
   GitHub: your existing token (full scopes)
   Permissions: --dangerously-skip-permissions
   Best for: trusted tasks on personal projects, prototyping

2. **Standard** (recommended) — Autonomous with guardrails.
   Network: all HTTPS/HTTP open, core services allowlisted
   GitHub: fine-grained token (push + PRs only, no admin)
   Permissions: --dangerously-skip-permissions
   Best for: feature work, bug fixes, autonomous coding

3. **Locked** — Maximum restriction.
   Network: only allowlisted domains (no general web)
   GitHub: fine-grained token, single repo only
   Permissions: Tier 2 scoped settings.json (deny destructive ops)
   Best for: untrusted code, running on shared infra, CI/CD
```

### Question 2: GitHub Permissions (drill down)

Based on profile choice, ask:

**If Open:**
> I'll use your existing `gh` token. It has these scopes: [show `gh auth status`].
> This includes repo admin (can delete repos). Are you OK with that, or want to restrict?

**If Standard:**
> I'll help you create a fine-grained GitHub token. Which repos should Claude have access to?
> (List their repos or ask them to name the ones they want.)

**If Locked:**
> I'll help you create a minimal GitHub token. Which single repo should Claude access?
> Should Claude be able to push directly, or only create PRs?

### Question 3: Web Access (only if Locked)

```
Should Claude be able to search the web for documentation and solutions?

a) **Yes, allow web research** — HTTPS open to all sites (default even in Locked)
b) **No, restrict to allowlist only** — Only Anthropic API, GitHub, npm
   Claude's WebSearch and WebFetch tools won't work with arbitrary sites.
```

### Question 4: Destructive Operations (only if Standard or Locked)

```
Should Claude be blocked from these operations?

- `rm -rf` (recursive delete)          [block by default]
- `git push --force`                   [block by default]
- `git reset --hard`                   [block by default]
- `gh repo delete`                     [always block]
- `sudo`                               [always block]
- `curl | bash` (pipe to shell)        [always block]

Any of these you want to ALLOW? (Most users keep all blocked.)
```

### Question 5: Entry Point Preference

```
How will you run the sandbox?

a) **Command line** (`bash .devcontainer/run.sh -p "task"`) — headless, scriptable
b) **VS Code** (Reopen in Container) — full IDE experience
c) **Both** — I'll set up both entry points
```

---

## Decision Matrix

After the interview, map answers to configuration:

### Firewall (`init-firewall.sh`)

| Setting | Open | Standard | Locked |
|---------|------|----------|--------|
| Anthropic API | allow | allow | allow |
| GitHub IPs | allow | allow | allow |
| npm registry | allow | allow | allow |
| HTTPS (any) | allow | allow | ask user |
| HTTP (any) | allow | allow | block |
| SSH (port 22) | allow | allow | allow |
| Non-HTTP protocols | block | block | block |

### GitHub Token

| Setting | Open | Standard | Locked |
|---------|------|----------|--------|
| Token type | existing (classic) | fine-grained | fine-grained |
| Repo scope | all repos | selected repos | single repo |
| Contents | read+write | read+write | read+write |
| Pull requests | read+write | read+write | read+write |
| Issues | read+write | read+write | read-only |
| Administration | inherited | none | none |
| Actions | inherited | none | none |
| Secrets | inherited | none | none |

### Permissions (`settings.json` — only for Locked)

| Category | Open | Standard | Locked |
|----------|------|----------|--------|
| File read/write | skip-perms | skip-perms | allow |
| git operations | skip-perms | skip-perms | allow (no force) |
| rm -rf | skip-perms | skip-perms | deny |
| sudo | skip-perms | skip-perms | deny |
| WebSearch | skip-perms | skip-perms | allow |
| WebFetch | skip-perms | skip-perms | allow |
| Test runners | skip-perms | skip-perms | allow |
| Shell commands | skip-perms | skip-perms | allow (curated) |

---

## Generation Templates

### Dockerfile (same for all profiles)

Generate from `.devcontainer/Dockerfile` template. Key components:
- Base: `node:20`
- Tools: git, zsh, fzf, gh, jq, vim, nano
- Firewall: iptables, ipset, iproute2, dnsutils, aggregate
- Shell: zsh with powerline10k, history persisted to `/commandhistory`
- Claude Code: `npm install -g @anthropic-ai/claude-code@latest`
- Non-root user: `node`
- Sudoers: only `init-firewall.sh` allowed

### devcontainer.json

```json
{
  "name": "Claude Code Sandbox",
  "build": { "dockerfile": "Dockerfile" },
  "runArgs": ["--cap-add=NET_ADMIN", "--cap-add=NET_RAW"],
  "remoteUser": "node",
  "mounts": [
    "source=claude-code-bashhistory-${devcontainerId},target=/commandhistory,type=volume",
    "source=${localEnv:HOME}/.claude,target=/home/node/.claude,type=bind",
    "source=${localEnv:HOME}/.ssh,target=/home/node/.ssh,type=bind,readonly"
  ],
  "containerEnv": {
    "NODE_OPTIONS": "--max-old-space-size=4096",
    "CLAUDE_CONFIG_DIR": "/home/node/.claude",
    "GH_TOKEN": "${localEnv:GH_TOKEN}"
  },
  "workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,consistency=delegated",
  "workspaceFolder": "/workspace",
  "postStartCommand": "sudo /usr/local/bin/init-firewall.sh && if [ -n \"$GH_TOKEN\" ]; then gh auth setup-git; fi",
  "waitFor": "postStartCommand"
}
```

### run.sh

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
GH_TOKEN="${GH_TOKEN:-$(gh auth token 2>/dev/null)}"

docker build -t claude-sandbox "$SCRIPT_DIR"

if [ $# -eq 0 ]; then
  docker run -it --rm \
    --cap-add=NET_ADMIN --cap-add=NET_RAW \
    -v "$HOME/.claude:/home/node/.claude" \
    -v "$HOME/.ssh:/home/node/.ssh:ro" \
    -v "claude-sandbox-history:/commandhistory" \
    -e "GH_TOKEN=$GH_TOKEN" \
    -v "$PROJECT_DIR:/workspace" \
    claude-sandbox zsh
else
  docker run -it --rm \
    --cap-add=NET_ADMIN --cap-add=NET_RAW \
    -v "$HOME/.claude:/home/node/.claude" \
    -v "$HOME/.ssh:/home/node/.ssh:ro" \
    -v "claude-sandbox-history:/commandhistory" \
    -e "GH_TOKEN=$GH_TOKEN" \
    -v "$PROJECT_DIR:/workspace" \
    claude-sandbox claude --dangerously-skip-permissions "$@"
fi
```

For **Locked** profile, replace `--dangerously-skip-permissions` with no flag (use settings.json).

### init-firewall.sh

Generate the full firewall script. Key variation points:

**Open / Standard profiles:**
```bash
# Allow outbound HTTPS/HTTP for web research
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
```

**Locked profile (no general web):**
Omit the above lines. Only allowlisted domains (via ipset) are reachable.

**Locked profile (web research allowed):**
Add only HTTPS, not HTTP:
```bash
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
```

---

## GitHub Token Setup Script

Walk the user through this interactively:

### For Standard / Locked profiles:

```
To create a fine-grained GitHub token:

1. Open: https://github.com/settings/tokens?type=beta
2. Click "Generate new token"
3. Name: "claude-sandbox" (or whatever you like)
4. Expiration: 90 days (recommended)
5. Repository access: "Only select repositories" → pick: [REPOS]
6. Permissions:
   - Contents: Read and write
   - Pull requests: Read and write
   - Issues: Read and write [Standard] / Read-only [Locked]
   - Metadata: Read-only (auto-selected)
   - Everything else: No access
7. Click "Generate token"
8. Copy the token (starts with github_pat_)
```

Then help them set it up:

```bash
# Add to ~/.zshrc (for devcontainer)
echo 'export GH_TOKEN="github_pat_..."' >> ~/.zshrc

# Or set it for this session only
export GH_TOKEN="github_pat_..."

# Verify
GH_TOKEN="github_pat_..." gh auth status
```

### For Open profile:

```bash
# Just export your existing token
echo 'export GH_TOKEN=$(gh auth token 2>/dev/null)' >> ~/.zshrc
```

---

## Post-Setup Verification

After generating all files, run this checklist:

```bash
# 1. Build the image
docker build --no-cache -t claude-sandbox .devcontainer/

# 2. Start container and verify
bash .devcontainer/run.sh

# Inside container, verify:
claude --version                    # Claude Code installed
gh auth status                      # GitHub token works
curl -s https://api.github.com/zen  # GitHub API reachable
curl -s https://example.com -o /dev/null -w "%{http_code}"  # HTTPS works (if allowed)
echo "test" > /tmp/test && rm /tmp/test  # Basic file ops work
git status                          # Git works in /workspace
```

Report results to the user in a summary table.

---

## Memory / Plans Setup

After the container is working, offer to set up memory sharing:

```
Your Claude Code memory (learned patterns, preferences) is stored per-project.
Inside the container, the project path is /workspace, so Claude looks for
memory at ~/.claude/projects/-workspace/memory/.

Want me to link your existing memory so the container Claude has the same
context as your host Claude?
```

If yes:
```bash
# Find the host project key
HOST_KEY=$(ls ~/.claude/projects/ | grep "$(basename $(pwd))" | head -1)
if [ -n "$HOST_KEY" ] && [ -d ~/.claude/projects/$HOST_KEY/memory ]; then
  mkdir -p ~/.claude/projects/-workspace
  ln -s ../$HOST_KEY/memory ~/.claude/projects/-workspace/memory
  echo "Linked: -workspace/memory → $HOST_KEY/memory"
fi
```

Plans at `~/.claude/plans/` are automatically visible since `~/.claude` is bind-mounted.
