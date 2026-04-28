#!/usr/bin/env bash
# B11_claude_settings_tampering.sh — R-004 AC0 catches `.claude/settings.json[hooks]`
# field tampering via partial-JSON canonicalized hashing.
#
# Precondition: INTEGRITY_SKIP and CI unset (battery::assert_env_hygiene).
# Fixture: bypass_seed_claude_settings writes a minimal .claude/settings.json
#          with non-empty `hooks` field, then `ag integrity update` baselines.
# Attack: modify the `hooks` field (add a no-op entry); stage benign state file;
#         commit.
# Expected: AC0 blocks because the canonical hash of `.claude/settings.json[hooks]`
#           changed.
#
# Code path traced:
#   integrity.py _PARTIAL_JSON_PATHS (line 87-91) includes
#       (".claude/settings.json", "hooks") →
#   _hash_partial_json (line 146-169) extracts settings.json["hooks"], canonicalizes,
#       SHA-256s →
#   compute_baseline persists the hash (initial integrity update) →
#   verify_all on next commit recomputes; new hash differs → mismatch →
#   GateResult.from_reason(messages.INTEGRITY_TAMPERED) at precommit_gate.py:362.

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e
    scaffold_project "$profile"
    bypass_seed_plan_approved
    # Seeder writes .claude/settings.json with {"hooks":{"PreToolUse":[]}} and
    # runs `ag integrity update` to baseline it. Without this seed, install.sh
    # never creates .claude/, _enumerate_targets silently skips the missing
    # partial-JSON target, and B11 has no attack surface.
    bypass_seed_claude_settings 2>/dev/null

    if [[ ! -f .agentic/integrity.json ]]; then
        echo "SKIP-by-design|integrity baseline absent after seed (env-dependent)|R-004:integrity.py"
        exit 0
    fi

    # Verify the baseline actually included .claude/settings.json[hooks];
    # if not, the seed's `ag integrity update` may have failed silently.
    if ! grep -q "claude/settings.json" .agentic/integrity.json 2>/dev/null; then
        echo "SKIP-by-design|integrity baseline lacks .claude/settings.json entry|R-004:integrity.py"
        exit 0
    fi

    # Attack: modify the hooks field. Use python to keep the JSON valid.
    python3 -c "
import json
p = '.claude/settings.json'
with open(p) as f:
    data = json.load(f)
data.setdefault('hooks', {}).setdefault('PreToolUse', []).append({'tampered': True})
with open(p, 'w') as f:
    json.dump(data, f, indent=2)
"

    # Stage a benign change to make the commit non-empty.
    echo "B11 marker $(date +%s)" >> .agentic/journal/JOURNAL.md
    git add .agentic/journal/JOURNAL.md

    set +e
    out=$(git commit -m "B11 attack: settings.json hooks tampering" 2>&1)
    rc=$?
    set -e

    code_path="precommit_gate.check_integrity:362 (R-004 partial-JSON path)"

    if [[ $rc -eq 0 ]]; then
        echo "FAIL|settings.json hooks tampering not detected — AC0 missed it|$code_path"
    elif bypass_assert_gate_blocked_by_ac "AC0" "precommit"; then
        # Review fix #1: structured event assertion.
        echo "PASS|AC0 caught settings.json[hooks] tampering (gate_blocked event with AC0; partial-JSON hash mismatch)|$code_path"
    else
        ev=$(echo "$out" | head -3 | tr '\n' ';' | sed 's/|/_/g')
        echo "FAIL|blocked but not by AC0; no AC0 in gate_blocked event; output: $ev|$code_path"
    fi
)
