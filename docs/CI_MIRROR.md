# CI Mirror — `agentic-gate.yml`

The Agentic Framework's Tier 0 enforcement (R-001 pre-commit gate, R-002 pre-push
gate) runs locally in a separate process from any agent session. **This is
already strong enforcement** — agents inside the session can't disable it
without tampering with hook files (which R-004 hash baselines catch).

This optional **CI mirror** runs the same gates GitHub-side on every push and
PR-merge. It is **belt-and-suspenders**: if a determined human bypasses the
local gate (e.g., `chmod +x` over the hook + `git commit --no-verify`), GitHub
still blocks the merge.

## When you want it

- **Multi-contributor repos.** Local hooks live in `.git/hooks/`, which are not
  shared. New clones don't get them until they run `ag hooks register` (R-015,
  WIP) — so until then a fresh contributor can land changes through gaps the
  CI mirror catches.
- **Compliance contexts.** GDPR / SOC2 / HIPAA reviewers want the same checks
  enforced from a system the developer can't control. The CI mirror provides
  that audit trail (workflow logs + uploaded `events.jsonl`).
- **Fork PRs.** Local hooks never run on a fork's branch; the CI mirror does.
  The PR-comment step gracefully no-ops on fork PRs (no write permission), but
  the failure status itself still blocks merge if you require it.

## When you don't need it

- Single-developer projects with a clean hook install.
- Repos where the local gate plus R-004 integrity baseline already meets your
  threat model.
- Non-GitHub remotes (GitLab/Bitbucket templates: planned follow-up if
  requested).

## Setup

1. Copy the template into your repository:

   ```bash
   mkdir -p .github/workflows
   cp .agentic/lib/init/templates/.github/workflows/agentic-gate.yml \
      .github/workflows/agentic-gate.yml
   ```

2. Commit and push. The workflow runs on every push to `main` and every PR
   targeting `main`.

3. Optional: require the `Tier 0 gates (CI mirror)` check in your branch
   protection rules so PRs can't merge while it's failing.

## What it does

| Step | Behavior |
|---|---|
| Checkout | `fetch-depth: 0` so range checks (R-002 migration validation) see history. |
| Pre-commit gate | `python3 .agentic/lib/hooks/precommit_gate.py --ci-mode --verbose`. |
| Pre-push gate | `python3 .agentic/lib/hooks/prepush_gate.py --ci-mode --verbose`. |
| Artifact upload | `precommit-gate.log`, `prepush-gate.log`, `verification.json`, `events.jsonl`. |
| Job summary | Markdown table of exit codes posted to the workflow's "Summary" tab. |
| PR comment | **On failure only** (success is silent). The comment is upserted via a marker so re-runs replace the prior comment. |
| Final exit | The job fails if either gate's exit code is non-zero. |

`continue-on-error: true` is set on each gate step so a pre-commit failure
doesn't skip the pre-push step — both run, then the final step decides the
job's outcome from the combined output.

## Behavior the mirror does NOT change

- The CI mirror is **read-only verification**. It never edits files, opens
  PRs, or pushes commits.
- It does not run autonomous agents or invoke any LLM. The same deterministic
  checks that fire locally are the only thing that runs in CI.
- `ag commit --skip-gate "<reason>"` and `ag push --skip-gate "<reason>"`
  audit trails do **not** exempt the CI mirror — by design. Local skips are
  for emergencies; if a skip lands and the gate would have caught something,
  CI catches it.

## Honest limits

- **Self-hosted runners**: this template assumes `ubuntu-latest`. On
  self-hosted runners, ensure Python 3.11+, Git, and `pyyaml` are available.
- **Long jobs**: integration tests in `prepush_gate.py` run the project's
  configured test suite. Set `STACK.md` `test_command` to a CI-friendly
  command (or a `ci_test_command` override if you add one) — the gate respects
  whatever you've configured. Default timeout is 20 minutes.
- **GitHub-only**: GitLab CI, Bitbucket Pipelines, Jenkins templates are
  planned follow-ups. The Python gates themselves are CI-agnostic; mirror
  templates for other systems are mechanical translations.
- **R-004 integrity**: the CI mirror does not currently regenerate the
  integrity baseline. Tampering with `.agentic/lib/hooks/*.py` between the
  local run and the CI run trips `INTEGRITY_TAMPERED` only locally; CI
  validates the committed state, which is the authoritative copy.

## Troubleshooting

**The job fails with "no test command in STACK.md"** — that's the gate
correctly reporting a missing `test_command` key. Add one in `STACK.md`. The
gate skips test execution when no command is configured locally; in CI mode
it surfaces the gap.

**The PR comment isn't posted on a fork PR** — fork PRs run with `pull_request`
event and do not get write access. Either move to `pull_request_target`
(security implications — read the GitHub docs first) or accept that fork PRs
fail loudly via the failed check status without an inline comment.

**I want the mirror to also run a critic (R-205)** — the CI mirror is Tier 0
only by design. Critic invocation requires LLM access (cost, secrets, latency),
and structurally the critic belongs in the local Tier 2 path. R-205 will add a
separate optional `agentic-critic.yml` template once Tier 2 ships.
