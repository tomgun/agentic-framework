# Agentic Framework (Template Repo)

This repository contains a portable agentic development framework under `agentic/`.

## For GitHub visitors
- If you’re evaluating the framework: start at `agentic/README.md`.
- If you copied this into a real project repo: this `README.md` is expected to be **replaced** by your project’s README.

## What to copy into a new project
Copy the `agentic/` folder into your project repo root (i.e., into the top-level directory of your project repository).

The framework also expects a small set of **repo-root bootstrap artifacts** (e.g. `STACK.md`, `STATUS.md`, `CONTEXT_PACK.md`, `AGENTS.md`, and `spec/*`) — these are created by the scaffold step below, so you don’t manually copy them.

## Init (agent-driven)
Developer goal: only talk to the agent. The agent can run scripts for efficiency.

Step 0: agent scaffolds all required files/folders (so everything exists immediately):

```bash
bash agentic/init/scaffold.sh
```

Step 1: run the agent-guided init planning session:
- Open your agent and point it to `agentic/init/init_playbook.md`

## Quick resume

```bash
bash agentic/tools/brief.sh
bash agentic/tools/report.sh
```


