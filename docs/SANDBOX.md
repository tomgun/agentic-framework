# Sandbox: Running Claude in Docker

Run Claude Code autonomously in a sandboxed Docker container with network isolation, filesystem boundaries, and configurable permissions.

## Why sandbox?

When Claude runs with `--dangerously-skip-permissions`, it executes commands without asking. The sandbox limits what damage a bad command can do:

| Without sandbox | With sandbox |
|---|---|
| Can read/write any file on your machine | Can only access the mounted project directory |
| Can reach any network endpoint | Firewall limits outbound traffic |
| Can run `rm -rf /` | Limited to container — host is untouched |
| Can exfiltrate secrets anywhere | Non-HTTP protocols blocked |

## Quick start

### Option A: Command line (`run.sh`)

```bash
# Interactive shell — drop into container, run claude manually
bash .devcontainer/run.sh

# One-shot autonomous task (skips all permission prompts)
bash .devcontainer/run.sh -p "fix the failing tests and create a PR"
```

`run.sh` automatically extracts your GitHub token from macOS Keychain, mounts your project + auth, starts the firewall, and launches Claude.

### Option B: VS Code Dev Container

1. Open the project in VS Code
2. Install the **Dev Containers** extension
3. Add `export GH_TOKEN=$(gh auth token 2>/dev/null)` to your `~/.zshrc` (needed because VS Code can't access macOS Keychain inside the container)
4. `Cmd+Shift+P` → "Reopen in Container"
5. Wait for build + firewall init
6. Open terminal, run `claude`

### Two entry points, one image

`run.sh` and `devcontainer.json` both build the same `Dockerfile` but configure mounts and env vars independently:

| | `run.sh` | `devcontainer.json` |
|---|---|---|
| **Used by** | Command line | VS Code "Reopen in Container" |
| **GitHub auth** | Auto-extracts `GH_TOKEN` from Keychain | Reads `GH_TOKEN` from host env |
| **Permission mode** | `--dangerously-skip-permissions` (one-shot) | Interactive (you choose) |
| **History** | Named Docker volume | Named Docker volume |

They share the `Dockerfile` and `init-firewall.sh`. Everything else is configured separately in each.

## What the container can access

### Filesystem mounts

The container has exactly these mounts. Nothing else from your host is visible.

```
Host                            → Container              Access
───────────────────────────────────────────────────────────────
Your project directory          → /workspace             read/write
~/.claude (auth, plans, memory) → /home/node/.claude     read/write
~/.ssh (SSH keys)               → /home/node/.ssh        read-only
Docker volume (zsh history)     → /commandhistory        read/write
GH_TOKEN env var                → GH_TOKEN               env var
```

There is no mount for your home directory, other projects, or system files. Docker bind mounts are explicit — unmounted paths don't exist inside the container.

**Verify it yourself** (from inside the container):
```bash
ls /                    # Standard Linux root, not your Mac
ls /workspace           # Your project — the only host code visible
cat /proc/mounts        # Shows exactly what's bind-mounted
ls /Users 2>/dev/null   # "No such file or directory"
```

### Network (firewall)

The `init-firewall.sh` script runs at container start and sets up iptables rules. Default policy is **DROP** — only explicitly allowed traffic gets through.

**Allowed outbound:**

| Destination | Why |
|---|---|
| `api.anthropic.com`, `auth.anthropic.com`, `console.anthropic.com` | Claude Code API |
| GitHub IPs (fetched dynamically from `/meta`) | git push/pull, PRs, API |
| `registry.npmjs.org` | Package installs |
| `sentry.io`, `statsig.anthropic.com` | Telemetry |
| VS Code marketplace domains | Extension installs |
| **Any HTTPS (port 443) / HTTP (port 80)** | Web research — see below |
| DNS (UDP 53), SSH (TCP 22), localhost | Infrastructure |

**Blocked:**
- All non-HTTP/HTTPS protocols (raw TCP, SMTP, FTP, etc.)
- All UDP except DNS

### Web research (WebSearch / WebFetch)

HTTPS and HTTP outbound are **open by default** so Claude can use `WebSearch` and `WebFetch` tools for research — looking up documentation, searching for solutions, fetching API references, etc. This is essential for autonomous agents doing real work.

The firewall still provides value even with open HTTP/HTTPS:
- Non-web protocols are blocked (no SMTP exfiltration, no raw TCP)
- Combined with container filesystem isolation, the attack surface is small
- Claude can browse but can't install arbitrary system packages or reach internal services on non-HTTP ports

To restrict web access (strict mode), see [Adjusting the firewall](#adjusting-the-firewall).

**Verify web research works** (from inside the container):
```bash
# These should work:
curl -s https://api.github.com/zen
curl -s https://example.com -o /dev/null -w "%{http_code}"

# This should fail (non-HTTP protocol):
curl --connect-timeout 3 telnet://example.com:25
```

## Security model

### Three tiers of trust

| Tier | How to run | What Claude can do | Best for |
|---|---|---|---|
| **Tier 1: Sandbox** | `run.sh -p "task"` | Anything (but firewall + container limit blast radius) | Autonomous tasks, CI/CD |
| **Tier 2: Scoped** | `claude` with `.claude/settings.json` | Only allowed commands (see [Permissions](#customizing-permissions)) | Semi-autonomous with guardrails |
| **Tier 3: Interactive** | `claude` (default) | Asks before every action | Maximum control |

### What can still go wrong (and mitigations)

Even with the sandbox, some risks remain. Here's what to think about:

#### 1. Destructive git operations

Claude can `git push --force` or delete remote branches. GitHub IPs are allowed through the firewall.

**Mitigation: branch protection rules**

Set these on GitHub (Settings → Branches → Branch protection rules):
- Require pull request reviews before merging
- Do not allow force pushes
- Do not allow deletions
- Require status checks to pass

These are server-side — Claude can't bypass them even with full container access.

#### 2. GitHub API permissions (`gh` CLI)

The `GH_TOKEN` env var gives Claude access to the GitHub API. Your token's scopes determine what it can do.

**The problem with classic tokens**: the default `repo` scope grants everything — push, delete repos, read secrets. You can check your current scopes:

```bash
gh auth status
# Token scopes: 'admin:public_key', 'gist', 'read:org', 'repo'  ← too broad
```

**How auth flows into the container:**

On macOS, `gh` stores tokens in the system **Keychain**, not in config files. Mounting `~/.config/gh` into a Linux container doesn't work — the Keychain doesn't exist there. Instead:

- **`run.sh`**: Automatically runs `gh auth token` on the host, extracts the real token, and passes it as `GH_TOKEN` env var. No setup needed.
- **`devcontainer.json`**: Reads `GH_TOKEN` from the host environment. Add `export GH_TOKEN=$(gh auth token 2>/dev/null)` to your `~/.zshrc`, then reopen VS Code.

On container start, `gh auth setup-git` configures git to use the token for HTTPS operations.

**Recommended: use a fine-grained personal access token**

For tighter control, create a dedicated token at [github.com/settings/tokens?type=beta](https://github.com/settings/tokens?type=beta):

1. Set **Repository access** to "Only select repositories" → pick your project repo(s)
2. Grant these permissions:

| Permission | Access | Why |
|---|---|---|
| Contents | Read and write | Push commits, read files |
| Pull requests | Read and write | Create/update PRs |
| Issues | Read and write | Read/comment on issues |
| Metadata | Read-only | Required by GitHub |

3. Permissions you should **NOT** grant:

| Permission | Risk |
|---|---|
| Administration | Can **delete repos**, change settings, manage deploy keys |
| Actions | Can trigger/cancel CI workflows, read logs |
| Environments / Secrets | Can read deployment secrets and variables |
| Organization permissions | Can modify org-wide settings |

4. Use the fine-grained token instead of your default one:

```bash
# Option A: Set as default for sandbox use
export GH_TOKEN="github_pat_..."   # in ~/.zshrc

# Option B: Pass directly to run.sh
GH_TOKEN="github_pat_..." bash .devcontainer/run.sh -p "task"
```

Now Claude can push and create PRs but **cannot** delete repos, read secrets, or modify CI pipelines — the token simply doesn't have those permissions.

#### 3. Secrets in the workspace

If your project has `.env` files, credentials, or API keys, Claude can read and potentially log them.

**Mitigation:** Use `.gitignore` and `.dockerignore` to exclude secrets from the mounted workspace. Or mount the workspace read-only and give write access to specific directories:

```json
"workspaceMount": "source=${localWorkspaceFolder},target=/workspace,type=bind,readonly",
"mounts": [
    "source=${localWorkspaceFolder}/.git,target=/workspace/.git,type=bind",
    "source=${localWorkspaceFolder}/src,target=/workspace/src,type=bind"
]
```

#### 4. Auth token exposure

`~/.claude` is bind-mounted into the container (needed for authentication). This includes your Anthropic API credentials.

**Mitigation:** The firewall limits where tokens can be sent. For maximum isolation, mount only what's needed:

```json
"mounts": [
    "source=${localEnv:HOME}/.claude/credentials.json,target=/home/node/.claude/credentials.json,type=bind,readonly",
    "source=${localEnv:HOME}/.claude/projects,target=/home/node/.claude/projects,type=bind",
    "source=${localEnv:HOME}/.claude/plans,target=/home/node/.claude/plans,type=bind,readonly"
]
```

## Customizing the sandbox

### Adjusting the firewall

Edit `.devcontainer/init-firewall.sh`.

**Example: Block all web access (strict mode)**

Remove or comment out the HTTPS/HTTP lines:
```bash
# Remove these to block general web access:
# iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
# iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
```

Claude will still reach Anthropic API, GitHub, and npm (via the ipset allowlist), but `WebSearch` and `WebFetch` will fail for arbitrary sites.

**Example: Add a custom domain to the allowlist**

```bash
# Add to the domain resolution loop in init-firewall.sh:
for domain in \
    "registry.npmjs.org" \
    "api.anthropic.com" \
    ...
    "your-internal-api.company.com"; do   # ← add here
```

This is useful in strict mode (no general HTTPS) when you want to allow specific internal services.

### Customizing permissions (Tier 2)

Instead of `--dangerously-skip-permissions`, use a settings file to allow specific commands:

```json
// .claude/settings.json (checked into repo)
{
  "permissions": {
    "allow": [
      "Read", "Edit", "Write", "Glob", "Grep",
      "WebSearch", "WebFetch",
      "Bash(git *)",
      "Bash(npm test *)",
      "Bash(bash tests/*)",
      "Bash(bash .agentic/*)",
      "Bash(ls *)", "Bash(mkdir *)", "Bash(cp *)"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Bash(sudo *)",
      "Bash(curl * | bash*)",
      "Bash(git push --force *)",
      "Bash(gh repo delete *)"
    ]
  }
}
```

The deny list takes precedence. This gives Claude autonomy for normal development while blocking destructive operations.

Generate a Tier 2 settings file automatically:
```bash
ag auto init            # reads STACK.md, generates .claude/settings.json
ag auto init --dry-run  # preview without writing
```

### Sharing plans and memory with the container

Claude Code stores plans at `~/.claude/plans/` and project memory at `~/.claude/projects/<path-key>/memory/`. Inside the container, the project path is `/workspace`, so Claude looks for memory at `~/.claude/projects/-workspace/memory/`.

**Option A: Symlink (recommended for single project)**

On your host machine:
```bash
cd ~/.claude/projects/-workspace
ln -s ../-Users-yourname-code-yourproject/memory memory
```

Plans work automatically since `~/.claude/plans/` is shared via the bind mount.

**Option B: Copy plans into the repo**

```bash
# From host — copy the plan into git-tracked location
cp ~/.claude/plans/random-name.md .agentic/journal/plans/descriptive-name-plan.md
```

This is the most durable approach — plans become part of the repo and are visible everywhere.

## Architecture overview

```
┌─────────────────────────────────────────────────────┐
│  Docker Container (node:20, non-root user)          │
│                                                     │
│  ┌──────────────┐  ┌───────────────────────────┐   │
│  │ Claude Code   │  │ iptables firewall         │   │
│  │ (node process)│  │ ┌───────────────────────┐ │   │
│  │               │  │ │ Allowlist:            │ │   │
│  │ Runs with     │  │ │  - Anthropic API      │ │   │
│  │ --dangerously-│  │ │  - GitHub (dynamic)   │ │   │
│  │ skip-perms    │  │ │  - npm registry       │ │   │
│  │  (Tier 1)     │  │ │  - HTTPS/HTTP (any)   │ │   │
│  │               │  │ │  - DNS, SSH, localhost │ │   │
│  │ OR with       │  │ ├───────────────────────┤ │   │
│  │ settings.json │  │ │ Blocked:              │ │   │
│  │  (Tier 2)     │  │ │  - All other protocols│ │   │
│  └──────────────┘  │ └───────────────────────┘ │   │
│                     └───────────────────────────┘   │
│                                                     │
│  Mounts:                                            │
│   /workspace         ← project dir (bind, rw)      │
│   /home/node/.claude ← auth + config (bind, rw)    │
│   /home/node/.ssh    ← SSH keys (bind, ro)         │
│   /commandhistory    ← zsh history (volume)         │
│                                                     │
│  Env: GH_TOKEN ← extracted from host keychain       │
│                                                     │
│  NOT mounted:                                       │
│   /Users/*, /home/*, other projects, system files   │
└─────────────────────────────────────────────────────┘
```

## Troubleshooting

**"Permission denied" when running firewall**
The container needs `NET_ADMIN` and `NET_RAW` capabilities. These are set in `devcontainer.json` (`runArgs`) and `run.sh` (`--cap-add`). If using a different orchestrator, ensure these capabilities are granted.

**Claude can't authenticate**
Check that `~/.claude` is properly mounted. Inside the container:
```bash
ls /home/node/.claude/
# Should contain auth files
```

**`gh` / `git push` fails with "authentication failed" or "could not read Username"**
On macOS, `gh` stores tokens in the system Keychain, which doesn't exist inside Linux containers. The fix:
- **`run.sh`**: Handled automatically — extracts token via `gh auth token` on the host.
- **`devcontainer.json`**: Add `export GH_TOKEN=$(gh auth token 2>/dev/null)` to `~/.zshrc`, restart VS Code.
- **Quick fix inside a running container**: `export GH_TOKEN="your_token_here"` then `gh auth setup-git`.

**WebSearch/WebFetch not working**
Verify HTTPS outbound is allowed:
```bash
curl -s https://example.com -o /dev/null -w "%{http_code}"
# Should return 200
```

If the firewall is in strict mode (no general HTTPS), these tools won't work. See [Adjusting the firewall](#adjusting-the-firewall).

**No command history (up arrow doesn't work)**
The container uses zsh. Ensure the history volume is mounted (`claude-sandbox-history` for `run.sh`, `claude-code-bashhistory-*` for devcontainer). If the image was built before the zsh history fix, rebuild with `--no-cache`:
```bash
docker build --no-cache -t claude-sandbox .devcontainer/
```

**DNS resolution failures after long sessions**
The firewall resolves domain IPs at container start. If provider IPs change during a long session, connections may break. Restart the container or re-run the firewall:
```bash
sudo /usr/local/bin/init-firewall.sh
```

**Plans/memory not visible**
See [Sharing plans and memory](#sharing-plans-and-memory-with-the-container). The most common issue is that the container uses `-workspace` as the project key while the host uses your full path.

**`gh` commands fail with 403**
Your GitHub token may lack the required scopes. Check with `gh auth status`. See [GitHub API permissions](#2-github-api-permissions-gh-cli) for how to set up a properly scoped token.

**Claude shows "let's get started" onboarding every time**
This happens when `~/.claude` is mounted as a Docker volume instead of a bind mount from the host. The bind mount (current default) shares your host's onboarding-complete state. Rebuild the container after updating to the latest `devcontainer.json`.
