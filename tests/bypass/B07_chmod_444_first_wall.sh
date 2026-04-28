#!/usr/bin/env bash
# B07_chmod_444_first_wall.sh — R-005 chmod 444 prevents direct edit (two-step).
#
# Attack: assert seeded F-9003 contract has mode 444; attempt direct write
#         via python3. Expect: chmod confirmed AND PermissionError(EACCES).
#
# Code path traced:
#   contract.sh::_contract_lock_shipped (line ~67-70) runs `chmod 444`. POSIX
#   denies write to non-owners; non-root user (uid != 0) on Linux+macOS hits
#   EACCES on `open(path, "a")`.
#
# Profile matrix (R-005 is profile-agnostic):
#   Linux + macOS, non-root, all profiles → PASS (chmod=444 + EACCES)
#   Windows → SKIP-by-design (chmod semantics differ)
#   Linux running as root (uid=0) → SKIP-by-design (root bypasses 444)

set -euo pipefail
B_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/battery.sh
source "$B_DIR/lib/battery.sh"

profile="${1:-discovery}"

(
    set -e

    # Pre-flight: skip on Windows or root.
    if [[ "${OS:-}" == "Windows_NT" ]]; then
        echo "SKIP-by-design|Windows: chmod semantics differ; R-005 not enforceable|R-005:contract.sh::_contract_lock_shipped"
        exit 0
    fi
    if [[ "$(id -u)" == "0" ]]; then
        echo "SKIP-by-design|root user: POSIX 444 doesn't deny root writes|R-005:contract.sh::_contract_lock_shipped"
        exit 0
    fi

    scaffold_project "$profile"
    bypass_seed_plan_approved
    bypass_seed_shipped_contract F-9003 >/dev/null

    code_path="R-005:contract.sh::_contract_lock_shipped"

    # Step 1: assert chmod 444 was applied.
    target="$CONTRACTS_DIR/F-9003.yaml"
    mode=""
    if mode=$(stat -c '%a' "$target" 2>/dev/null); then
        :  # GNU stat
    elif mode=$(stat -f '%p' "$target" 2>/dev/null); then
        mode="${mode: -3}"  # macOS stat returns full mode bits; take last 3
    fi

    if [[ "$mode" != "444" ]]; then
        echo "FAIL|chmod was not applied (mode=$mode); R-005 first-wall absent|$code_path"
        exit 0
    fi

    # Step 2: attempt direct write; expect PermissionError.
    set +e
    py_out=$(python3 -c "
import os, sys
target = os.environ['CONTRACTS_DIR'] + '/F-9003.yaml'
try:
    with open(target, 'a') as f:
        f.write('x')
    print('NO_ERROR')
except PermissionError:
    print('EACCES')
except OSError as e:
    print(f'OSERR:{e.errno}')
" 2>&1)
    set -e

    if [[ "$py_out" == "EACCES" ]]; then
        echo "PASS|chmod=444 + PermissionError on write (R-005 first wall holds)|$code_path"
    elif [[ "$py_out" == "NO_ERROR" ]]; then
        echo "FAIL|mode=444 but write succeeded (R-005 first wall NOT holding)|$code_path"
    else
        echo "FAIL|unexpected python output: $py_out|$code_path"
    fi
)
