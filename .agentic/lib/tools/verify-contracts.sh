#!/usr/bin/env bash
# verify-contracts.sh — Run structural assertions from YAML contracts
#
# Usage:
#   bash verify-contracts.sh [--json] [--feature F-XXXX] [--dir contracts_dir]
#
# Reads all .yaml files in spec/contracts/, runs each structural assertion's
# verify command, reports pass/fail per feature per assertion.
#
# Exit codes:
#   0 = all assertions passed (or no contracts)
#   1 = one or more assertions failed
#
# Depends on: paths.sh, contracts.py (Python)

set -euo pipefail

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
OUTPUT_JSON=0
FEATURE_ID=""
CONTRACTS_DIR_OVERRIDE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) OUTPUT_JSON=1; shift ;;
        --feature) FEATURE_ID="$2"; shift 2 ;;
        --dir) CONTRACTS_DIR_OVERRIDE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../paths.sh"

if [[ -n "$CONTRACTS_DIR_OVERRIDE" ]]; then
    CONTRACTS_DIR="$CONTRACTS_DIR_OVERRIDE"
fi
CONTRACTS_DIR="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

if [[ ! -d "$CONTRACTS_DIR" ]]; then
    if [[ "$OUTPUT_JSON" -eq 1 ]]; then
        echo '{"contracts": [], "summary": {"total": 0, "passed": 0, "failed": 0, "skipped": 0}}'
    else
        echo "No contracts directory: $CONTRACTS_DIR"
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Run verification via Python
# ---------------------------------------------------------------------------
PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import json
import sys
from pathlib import Path

sys.path.insert(0, '$ROOT_DIR/.agentic/lib')
from contracts import load_contract, load_all_contracts, verify_contract

contracts_dir = Path('$CONTRACTS_DIR')
project_root = Path('$ROOT_DIR')
feature_id = '$FEATURE_ID'
output_json = $OUTPUT_JSON

# Load contracts
if feature_id:
    contract_file = contracts_dir / f'{feature_id}.yaml'
    if not contract_file.exists():
        print(f'Contract not found: {contract_file}', file=sys.stderr)
        sys.exit(1)
    contracts = [load_contract(contract_file)]
else:
    contracts = load_all_contracts(contracts_dir)

# Verify each
results = []
total_pass = 0
total_fail = 0
total_skip = 0

for contract in contracts:
    result = verify_contract(contract, project_root)
    results.append(result)
    total_pass += result['passed']
    total_fail += result['failed']
    total_skip += result['skipped']

# Output
total_unshipped = 0
unshipped_details = []
for contract in contracts:
    us = contract.unshipped_assertions
    if us:
        total_unshipped += len(us)
        ids = ', '.join(a.id for a in us)
        unshipped_details.append((contract.id, ids))

if output_json:
    output = {
        'contracts': results,
        'summary': {
            'total': total_pass + total_fail + total_skip,
            'passed': total_pass,
            'failed': total_fail,
            'skipped': total_skip,
            'unshipped': total_unshipped,
        }
    }
    print(json.dumps(output, indent=2))
else:
    # Human-readable output
    for result in results:
        cid = result['contract_id']
        cname = result['contract_name']
        p = result['passed']
        f = result['failed']
        s = result['skipped']

        if f > 0:
            status = '✗'
        else:
            status = '✓'

        print(f'{status} {cid}: {cname} ({p} pass, {f} fail, {s} skip)')

        # Show details for failures
        for r in result['results']:
            if not r['passed'] and not r['skipped']:
                print(f'  ✗ {r[\"id\"]}: {r[\"output\"][:100]}')

    print()
    print(f'Summary: {total_pass} passed, {total_fail} failed, {total_skip} skipped')
    print(f'Contracts: {len(contracts)}')

    if unshipped_details:
        print(f'\n⚠ {total_unshipped} unshipped assertion(s):')
        for cid, ids in unshipped_details:
            print(f'  {cid}: {ids}')
        print('  Run: ag contract promote <feature-id>')

sys.exit(1 if total_fail > 0 else 0)
"
