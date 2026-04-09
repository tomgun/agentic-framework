#!/usr/bin/env bash
# commands/contract.sh — YAML contract management commands
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, PROFILE, color codes, paths.sh, settings.sh

cmd_contract() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        check)    _contract_check "$@" ;;
        coverage) _contract_coverage ;;
        pending)  _contract_pending ;;
        list)     _contract_list "$@" ;;
        tree)     _contract_tree ;;
        set)      _contract_set "$@" ;;
        add-assertion)    _contract_add_assertion "$@" ;;
        add-migration)    _contract_add_migration "$@" ;;
        migrations)       _contract_migrations "$@" ;;
        validate)         _contract_validate "$@" ;;
        create)           _contract_create "$@" ;;
        promote)          _contract_promote "$@" ;;
        help|--help|-h)   _contract_help ;;
        *)
            echo -e "${RED}Unknown contract subcommand: $subcmd${NC}"
            _contract_help
            return 1
            ;;
    esac
}

_contract_help() {
    echo -e "${BOLD}ag contract${NC} — YAML contract management"
    echo ""
    echo "  check [F-XXXX] [--recursive]  Run structural assertions (all or one feature)"
    echo "  coverage             Show assertions with/without tests"
    echo "  pending              Show features with non-empty user_input"
    echo "  list [--category X] [--persona X] [--platform X]  List contracts (with filters)"
    echo "  tree                 Show contract hierarchy"
    echo "  validate [F-XXXX]   Validate contract YAML (all or one)"
    echo "  create F-XXXX [--parent F-XXXX]  Create a new draft contract (--parent auto-assigns dotted child ID)"
    echo "  promote F-XXXX [AC-ID]  Promote planned/unshipped assertions to shipped"
    echo "  set F-XXXX KEY VAL  Set a contract field"
    echo "  add-assertion F-XXXX TEXT [--type structural|behavioral]"
    echo "  add-migration F-XXXX --trigger TYPE --reason TEXT"
    echo "  migrations [F-XXXX] [--trigger TYPE]  Show migration history"
    echo ""
    echo "Contracts live in: ${CONTRACTS_DIR:-$SPEC_DIR/contracts}"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

_contract_check() {
    local feature_id=""
    local recursive=0
    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --recursive|-r) recursive=1; shift ;;
            -*) shift ;;
            *) [[ -z "$feature_id" ]] && feature_id="$1"; shift ;;
        esac
    done

    if [[ ! -d "$contracts_dir" ]]; then
        echo -e "${YELLOW}No contracts directory: $contracts_dir${NC}"
        echo "Create one with: mkdir -p $contracts_dir"
        return 1
    fi

    if [[ -n "$feature_id" ]]; then
        local contract_file="$contracts_dir/${feature_id}.yaml"
        if [[ ! -f "$contract_file" ]]; then
            echo -e "${RED}Contract not found: $contract_file${NC}"
            return 1
        fi

        if [[ "$recursive" -eq 1 ]]; then
            echo -e "${BOLD}Verifying contract (recursive): $feature_id${NC}"
            echo ""
            _AG_CONTRACTS_DIR="$contracts_dir" \
            _AG_FEATURE_ID="$feature_id" \
            _AG_ROOT_DIR="$ROOT_DIR" \
            PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os, sys, json
from pathlib import Path
from contracts import load_contract, load_all_contracts, verify_contract

contracts_dir = Path(os.environ['_AG_CONTRACTS_DIR'])
feature_id = os.environ['_AG_FEATURE_ID']
root_dir = Path(os.environ['_AG_ROOT_DIR'])

# Load all contracts to find children
all_contracts = load_all_contracts(contracts_dir)
by_id = {c.id: c for c in all_contracts}

# Build parent→children map (O(n) instead of O(n^2))
children_map = {}
for c in all_contracts:
    if c.parent:
        children_map.setdefault(c.parent, []).append(c.id)

def collect_ids(fid):
    ids = [fid]
    for child_id in children_map.get(fid, []):
        ids.extend(collect_ids(child_id))
    return ids

check_ids = collect_ids(feature_id)
total_pass, total_fail, total_skip = 0, 0, 0

for cid in check_ids:
    if cid not in by_id:
        continue
    contract = by_id[cid]
    result = verify_contract(contract, root_dir)
    p, f, s = result['passed'], result['failed'], result['skipped']
    total_pass += p; total_fail += f; total_skip += s

    status = '✓' if f == 0 else '✗'
    indent = '  ' if cid != feature_id else ''
    print(f'{indent}{status} {cid}: {p} passed, {f} failed, {s} skipped')

    for r in result['results']:
        if not r['passed'] and not r['skipped']:
            print(f'    ✗ {r[\"id\"]}')
            if r['output']:
                for line in r['output'].split(chr(10))[:2]:
                    print(f'      {line}')

total_planned = sum(len(by_id[cid].unshipped_assertions) for cid in check_ids if cid in by_id)
print()
summary = f'Total: {total_pass} passed, {total_fail} failed, {total_skip} skipped ({len(check_ids)} contracts)'
if total_planned:
    summary += f', {total_planned} planned'
print(summary)
sys.exit(1 if total_fail > 0 else 0)
"
            return $?
        fi

        echo -e "${BOLD}Verifying contract: $feature_id${NC}"
        echo ""
        PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import sys, json
from pathlib import Path
from contracts import load_contract, verify_contract

contract = load_contract(Path('$contract_file'))
result = verify_contract(contract, Path('$ROOT_DIR'))
passed = result['passed']
failed = result['failed']
skipped = result['skipped']

for r in result['results']:
    if r['skipped']:
        print(f'  ⊘ {r[\"id\"]}: {r[\"reason\"]}')
    elif r['passed']:
        print(f'  ✓ {r[\"id\"]}')
    else:
        print(f'  ✗ {r[\"id\"]}')
        if r['output']:
            for line in r['output'].split(chr(10))[:3]:
                print(f'    {line}')

planned = len(contract.unshipped_assertions)
print()
summary = f'{passed} passed, {failed} failed, {skipped} skipped'
if planned:
    summary += f', {planned} planned (not yet implemented)'
print(summary)
sys.exit(1 if failed > 0 else 0)
"
        return $?
    fi

    # Check all contracts
    echo -e "${BOLD}Verifying all contracts${NC}"
    echo ""

    local total_pass=0
    local total_fail=0
    local total_skip=0
    local contract_count=0
    local failed_contracts=""

    for yaml_file in "$contracts_dir"/*.yaml; do
        [[ -f "$yaml_file" ]] || continue
        contract_count=$((contract_count + 1))
        local basename
        basename=$(basename "$yaml_file" .yaml)

        local result
        result=$(PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import json
from pathlib import Path
from contracts import load_contract, verify_contract

contract = load_contract(Path('$yaml_file'))
result = verify_contract(contract, Path('$ROOT_DIR'))
print(json.dumps(result))
" 2>&1)

        if [[ $? -ne 0 ]] || ! echo "$result" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
            echo -e "  ${RED}✗${NC} $basename (parse error)"
            total_fail=$((total_fail + 1))
            failed_contracts="$failed_contracts $basename"
            continue
        fi

        local p f s
        read p f s <<< $(echo "$result" | python3 -c "
import sys,json; d=json.load(sys.stdin)
print(d['passed'], d['failed'], d['skipped'])")

        total_pass=$((total_pass + p))
        total_fail=$((total_fail + f))
        total_skip=$((total_skip + s))

        if [[ "$f" -gt 0 ]]; then
            echo -e "  ${RED}✗${NC} $basename (${p} pass, ${f} fail, ${s} skip)"
            failed_contracts="$failed_contracts $basename"
        else
            echo -e "  ${GREEN}✓${NC} $basename (${p} pass, ${s} skip)"
        fi
    done

    echo ""
    echo -e "${BOLD}Summary:${NC} $contract_count contracts, $total_pass passed, $total_fail failed, $total_skip skipped"

    if [[ -n "$failed_contracts" ]]; then
        echo -e "${RED}Failed:${NC}$failed_contracts"
        return 1
    fi
    return 0
}

_contract_coverage() {
    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    if [[ ! -d "$contracts_dir" ]]; then
        echo -e "${YELLOW}No contracts directory${NC}"
        return 1
    fi

    echo -e "${BOLD}Contract Coverage Report${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import json
from pathlib import Path
from contracts import coverage_report

report = coverage_report(Path('$contracts_dir'))
total = report['total_assertions']
tested = report['with_tests']
verified = report['with_verify']
pct = report['coverage_pct']

print(f'  Total assertions:  {total}')
print(f'  With tests:        {tested}')
print(f'  With verify cmd:   {verified}')
print(f'  Coverage:          {pct}%')

gaps = report['gaps']
if gaps:
    print(f'\n  Gaps ({len(gaps)}):')
    for g in gaps[:20]:
        print(f'    {g[\"contract\"]} {g[\"assertion\"]}: {g[\"text\"][:60]}')
    if len(gaps) > 20:
        print(f'    ... and {len(gaps) - 20} more')
else:
    print('\n  No gaps — all assertions have tests or verify commands')
"
}

_contract_pending() {
    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    echo -e "${BOLD}Pending User Input${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
from pathlib import Path
from contracts import get_pending_user_input

pending = get_pending_user_input(Path('$contracts_dir'))
if not pending:
    print('  No pending user input')
else:
    for c in pending:
        print(f'  {c.id}: {c.name}')
        inp = c.user_input.strip()
        for line in inp.split(chr(10))[:3]:
            print(f'    > {line}')
        print()
    print(f'{len(pending)} contract(s) with pending input')
"
}

_contract_list() {
    local filter_category=""
    local filter_lifecycle=""
    local filter_persona=""
    local filter_platform=""
    local flat=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --category) filter_category="$2"; shift 2 ;;
            --lifecycle) filter_lifecycle="$2"; shift 2 ;;
            --persona) filter_persona="$2"; shift 2 ;;
            --platform) filter_platform="$2"; shift 2 ;;
            --flat) flat=1; shift ;;
            *) shift ;;
        esac
    done

    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    echo -e "${BOLD}Contracts${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
from pathlib import Path
from contracts import load_all_contracts

contracts = load_all_contracts(Path('$contracts_dir'))
category_filter = '$filter_category'
lifecycle_filter = '$filter_lifecycle'
persona_filter = '$filter_persona'
platform_filter = '$filter_platform'

if category_filter:
    contracts = [c for c in contracts if c.category == category_filter]
if lifecycle_filter:
    contracts = [c for c in contracts if c.lifecycle == lifecycle_filter]
if persona_filter:
    contracts = [c for c in contracts if persona_filter in c.personas]
if platform_filter:
    contracts = [c for c in contracts if platform_filter in c.platforms]

if not contracts:
    print('  No contracts found')
else:
    # Group by category
    by_cat = {}
    for c in contracts:
        by_cat.setdefault(c.category, []).append(c)

    for cat in sorted(by_cat):
        print(f'  [{cat}]')
        for c in by_cat[cat]:
            prot = ' 🔒' if c.protection == 'contract' else ''
            ac = len(c.assertions)
            personas_str = f' [{", ".join(c.personas)}]' if c.personas else ''
            print(f'    {c.id}  {c.lifecycle:<14} {c.name} ({ac} ACs){prot}{personas_str}')
        print()

    print(f'{len(contracts)} contract(s)')
"
}

_contract_tree() {
    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    echo -e "${BOLD}Contract Hierarchy${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
from pathlib import Path
from contracts import load_all_contracts

contracts = load_all_contracts(Path('$contracts_dir'))
by_id = {c.id: c for c in contracts}

# Find roots (no parent)
roots = [c for c in contracts if not c.parent]
children_map = {}
for c in contracts:
    if c.parent:
        children_map.setdefault(c.parent, []).append(c)

def print_tree(c, indent=0):
    prefix = '  ' * indent + ('├── ' if indent > 0 else '')
    ac = len(c.assertions)
    print(f'{prefix}{c.id} {c.name} [{c.lifecycle}] ({ac} ACs)')
    for child in children_map.get(c.id, []):
        print_tree(child, indent + 1)

for r in sorted(roots, key=lambda x: x.id):
    print_tree(r)

if not contracts:
    print('  No contracts found')
"
}

_contract_validate() {
    local feature_id="${1:-}"
    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    if [[ -n "$feature_id" ]]; then
        local contract_file="$contracts_dir/${feature_id}.yaml"
        if [[ ! -f "$contract_file" ]]; then
            echo -e "${RED}Contract not found: $contract_file${NC}"
            return 1
        fi
        echo -e "${BOLD}Validating: $feature_id${NC}"
        PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import sys; sys.path.insert(0, '$ROOT_DIR/.agentic/lib')
from contracts import validate_contract_file; from pathlib import Path
errors = validate_contract_file(Path('$contract_file'))
if errors:
    for e in errors: print(f'  ERROR: {e}')
    sys.exit(1)
else:
    print(f'  OK: $contract_file')
"
        return $?
    fi

    echo -e "${BOLD}Validating all contracts${NC}"
    echo ""
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import sys; sys.path.insert(0, '$ROOT_DIR/.agentic/lib')
from contracts import validate_contract_file; from pathlib import Path
contracts_dir = Path('$contracts_dir')
all_ok = True; count = 0
for f in sorted(contracts_dir.glob('*.yaml')):
    count += 1
    errors = validate_contract_file(f)
    if errors:
        all_ok = False; print(f'FAIL: {f.name}')
        for e in errors: print(f'  {e}')
    else:
        print(f'  OK: {f.name}')
print(f'\n{count} contract(s) checked')
sys.exit(0 if all_ok else 1)
"
    return $?
}

_contract_set() {
    local feature_id="${1:-}"
    local key="${2:-}"
    local value="${3:-}"

    if [[ -z "$feature_id" ]] || [[ -z "$key" ]] || [[ -z "$value" ]]; then
        echo -e "${RED}Usage: ag contract set F-XXXX KEY VALUE${NC}"
        echo "  Keys: lifecycle, protection, category, profile, user_input, since, notes"
        return 1
    fi

    # Validate feature ID format to prevent path traversal
    if ! echo "$feature_id" | grep -qE '^(F|NFR|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$'; then
        echo -e "${RED}Invalid feature ID format: $feature_id${NC}"
        return 1
    fi

    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"
    local contract_file="$contracts_dir/${feature_id}.yaml"

    if [[ ! -f "$contract_file" ]]; then
        echo -e "${RED}Contract not found: $contract_file${NC}"
        return 1
    fi

    # Pass values via env vars to prevent shell injection
    _AG_CONTRACT_FILE="$contract_file" \
    _AG_KEY="$key" \
    _AG_VALUE="$value" \
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os, sys
from pathlib import Path
from contracts import load_contract, save_contract

contract = load_contract(Path(os.environ['_AG_CONTRACT_FILE']))
key = os.environ['_AG_KEY']
value = os.environ['_AG_VALUE']

valid_keys = ['lifecycle', 'protection', 'category', 'profile', 'user_input', 'since', 'notes', 'name', 'description']
if key not in valid_keys:
    print(f'Invalid key: {key}')
    print('Valid keys: ' + ', '.join(valid_keys))
    sys.exit(1)

setattr(contract, key, value)
save_contract(contract, Path(os.environ['_AG_CONTRACT_FILE']))
print(f'Updated {contract.id}.{key} = {value}')
"
    return $?
}

_contract_add_assertion() {
    local feature_id="${1:-}"
    shift 2>/dev/null || true
    local text=""
    local atype="structural"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) atype="$2"; shift 2 ;;
            *) text="$1"; shift ;;
        esac
    done

    if [[ -z "$feature_id" ]] || [[ -z "$text" ]]; then
        echo -e "${RED}Usage: ag contract add-assertion F-XXXX \"description\" [--type structural|behavioral]${NC}"
        return 1
    fi

    if ! echo "$feature_id" | grep -qE '^(F|NFR|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$'; then
        echo -e "${RED}Invalid feature ID format: $feature_id${NC}"
        return 1
    fi

    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"
    local contract_file="$contracts_dir/${feature_id}.yaml"

    if [[ ! -f "$contract_file" ]]; then
        echo -e "${RED}Contract not found: $contract_file${NC}"
        return 1
    fi

    _AG_CONTRACT_FILE="$contract_file" \
    _AG_TEXT="$text" \
    _AG_TYPE="$atype" \
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os
from pathlib import Path
from contracts import load_contract, save_contract, Assertion

contract = load_contract(Path(os.environ['_AG_CONTRACT_FILE']))
text = os.environ['_AG_TEXT']
atype = os.environ['_AG_TYPE']

# Determine next AC ID
existing_nums = []
for a in contract.assertions:
    try:
        num = int(a.id.split('-')[1])
        existing_nums.append(num)
    except (IndexError, ValueError):
        pass
next_num = max(existing_nums, default=0) + 1
ac_id = f'AC-{next_num:03d}'

new_assertion = Assertion(id=ac_id, text=text, type=atype)
contract.assertions.append(new_assertion)
save_contract(contract, Path(os.environ['_AG_CONTRACT_FILE']))
print(f'Added {ac_id} to {contract.id}: {text}')
"
    return $?
}

_contract_add_migration() {
    local feature_id="${1:-}"
    shift 2>/dev/null || true
    local trigger=""
    local reason=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --trigger) trigger="$2"; shift 2 ;;
            --reason) reason="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$feature_id" ]] || [[ -z "$trigger" ]] || [[ -z "$reason" ]]; then
        echo -e "${RED}Usage: ag contract add-migration F-XXXX --trigger TYPE --reason \"reason\"${NC}"
        echo "  Triggers: external, implementation_discovery, user_request"
        return 1
    fi

    if ! echo "$feature_id" | grep -qE '^(F|NFR|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$'; then
        echo -e "${RED}Invalid feature ID format: $feature_id${NC}"
        return 1
    fi

    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"
    local contract_file="$contracts_dir/${feature_id}.yaml"

    if [[ ! -f "$contract_file" ]]; then
        echo -e "${RED}Contract not found: $contract_file${NC}"
        return 1
    fi

    _AG_CONTRACT_FILE="$contract_file" \
    _AG_TRIGGER="$trigger" \
    _AG_REASON="$reason" \
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os
from pathlib import Path
from datetime import date
from contracts import load_contract, save_contract, Migration

contract = load_contract(Path(os.environ['_AG_CONTRACT_FILE']))
today = date.today().isoformat()
trigger = os.environ['_AG_TRIGGER']
reason = os.environ['_AG_REASON']

# Determine next migration number for today
existing_today = [m for m in contract.migrations if m.date == today]
next_num = len(existing_today) + 1
mid = f'M-{today}-{next_num:03d}'

migration = Migration(
    id=mid, date=today, trigger=trigger, reason=reason,
    changes=[], approved_by='user',
)
contract.migrations.append(migration)
save_contract(contract, Path(os.environ['_AG_CONTRACT_FILE']))
print(f'Added migration {mid} to {contract.id}')
print(f'  Trigger: {trigger}')
print(f'  Reason: {reason}')
print(f'  Edit the contract to add specific changes to the migration.')
"
    return $?
}

_contract_migrations() {
    local feature_id="${1:-}"
    local filter_trigger=""

    shift 2>/dev/null || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --trigger) filter_trigger="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"

    echo -e "${BOLD}Migration History${NC}"
    echo ""

    _AG_CONTRACTS_DIR="$contracts_dir" \
    _AG_FEATURE_ID="${feature_id:-}" \
    _AG_TRIGGER_FILTER="${filter_trigger:-}" \
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os
from pathlib import Path
from contracts import load_all_contracts

contracts_dir = Path(os.environ['_AG_CONTRACTS_DIR'])
feature_id = os.environ.get('_AG_FEATURE_ID', '')
trigger_filter = os.environ.get('_AG_TRIGGER_FILTER', '')

if feature_id:
    from contracts import load_contract
    f = contracts_dir / f'{feature_id}.yaml'
    if not f.exists():
        print(f'Contract not found: {feature_id}')
        exit(1)
    contracts = [load_contract(f)]
else:
    contracts = load_all_contracts(contracts_dir)

total = 0
for c in contracts:
    migrations = c.migrations
    if trigger_filter:
        migrations = [m for m in migrations if m.trigger == trigger_filter]
    if not migrations:
        continue
    print(f'  {c.id}: {c.name}')
    for m in migrations:
        print(f'    {m.id}  [{m.trigger}]  {m.reason}')
        for ch in m.changes:
            print(f'      - {ch}')
    total += len(migrations)
    print()

if total == 0:
    print('  No migrations found')
else:
    print(f'{total} migration(s)')
"
}

_contract_create() {
    local feature_id=""
    local name="New Feature"
    local parent_id=""

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --parent) parent_id="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            -*) shift ;;
            *)
                if [[ -z "$feature_id" ]]; then
                    feature_id="$1"
                elif [[ "$name" == "New Feature" ]]; then
                    name="$1"
                fi
                shift
                ;;
        esac
    done

    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"
    mkdir -p "$contracts_dir"

    # If --parent provided, auto-assign dotted child ID
    if [[ -n "$parent_id" ]]; then
        # Validate parent ID
        source "$ROOT_DIR/.agentic/lib/ids.sh" 2>/dev/null || true
        if ! echo "$parent_id" | grep -qE "^(F|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$"; then
            echo -e "${RED}Invalid parent ID format: $parent_id${NC}"
            return 1
        fi

        local parent_contract="$contracts_dir/${parent_id}.yaml"
        if [[ ! -f "$parent_contract" ]]; then
            echo -e "${RED}Parent contract not found: $parent_contract${NC}"
            return 1
        fi

        # Auto-assign child ID via Python
        _AG_PARENT_ID="$parent_id" \
        _AG_NAME="$name" \
        _AG_CONTRACTS_DIR="$contracts_dir" \
        PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os, sys
from pathlib import Path
from contracts import Contract, Assertion, save_contract, load_contract, load_all_contracts
from ids import get_next_child_id, get_depth, MAX_DEPTH

parent_id = os.environ['_AG_PARENT_ID']
name = os.environ['_AG_NAME']
contracts_dir = Path(os.environ['_AG_CONTRACTS_DIR'])

# Depth guard
depth = get_depth(parent_id)
if depth >= MAX_DEPTH:
    print(f'Cannot create child of {parent_id}: depth {depth} is at maximum ({MAX_DEPTH})')
    sys.exit(1)

# Find existing children
all_contracts = load_all_contracts(contracts_dir)
existing_children = [c.id for c in all_contracts if c.parent == parent_id]
child_id = get_next_child_id(parent_id, existing_children)

contract_file = contracts_dir / f'{child_id}.yaml'
if contract_file.exists():
    print(f'Contract already exists: {contract_file}')
    sys.exit(1)

contract = Contract(
    id=child_id,
    name=name,
    lifecycle='exploring',
    description=f'Child feature of {parent_id}.',
    parent=parent_id,
    assertions=[
        Assertion(
            id='AC-001',
            text='TODO: First acceptance criterion',
            type='structural',
            draft=True,
        ),
    ],
    protection='none',
)
save_contract(contract, contract_file)

# Update parent's children list
parent_contract = load_contract(contracts_dir / f'{parent_id}.yaml')
if parent_contract.children is None:
    parent_contract.children = []
if child_id not in parent_contract.children:
    parent_contract.children.append(child_id)
    save_contract(parent_contract, contracts_dir / f'{parent_id}.yaml')

print(f'Created child contract: {child_id} (parent: {parent_id})')
print(f'  File: {contract_file}')
print(f'  Edit to add assertions, then run: ag contract validate {child_id}')
"
        return $?
    fi

    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: ag contract create F-XXXX [\"Feature Name\"] [--parent F-XXXX]${NC}"
        return 1
    fi

    # Validate feature ID (supports dotted IDs)
    if ! echo "$feature_id" | grep -qE '^(F|NFR|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$'; then
        echo -e "${RED}Invalid feature ID format: $feature_id${NC}"
        return 1
    fi

    local contract_file="$contracts_dir/${feature_id}.yaml"

    if [[ -f "$contract_file" ]]; then
        echo -e "${YELLOW}Contract already exists: $contract_file${NC}"
        return 1
    fi

    _AG_CONTRACT_FILE="$contract_file" \
    _AG_FEATURE_ID="$feature_id" \
    _AG_NAME="$name" \
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os
from pathlib import Path
from contracts import Contract, Assertion, save_contract

feature_id = os.environ['_AG_FEATURE_ID']
name = os.environ['_AG_NAME']
contract_file = os.environ['_AG_CONTRACT_FILE']

contract = Contract(
    id=feature_id,
    name=name,
    lifecycle='exploring',
    description='TODO: Describe what this feature does and why it exists.',
    assertions=[
        Assertion(
            id='AC-001',
            text='TODO: First acceptance criterion',
            type='structural',
            draft=True,
        ),
    ],
    protection='none',
)
save_contract(contract, Path(contract_file))
print(f'Created draft contract: {contract_file}')
print(f'  Edit to add assertions, then run: ag contract validate {feature_id}')
"
    return $?
}

_contract_promote() {
    local feature_id="${1:-}"
    local ac_id="${2:-}"

    if [[ -z "$feature_id" ]]; then
        echo -e "${RED}Usage: ag contract promote F-XXXX [AC-ID]${NC}"
        echo "  Promotes planned/unshipped assertions to shipped."
        echo "  Without AC-ID: promotes all unshipped assertions."
        return 1
    fi

    if ! echo "$feature_id" | grep -qE '^(F|NFR|DEV|E)-[0-9]{3,}(\.[1-9][0-9]*)*$'; then
        echo -e "${RED}Invalid feature ID format: $feature_id${NC}"
        return 1
    fi

    local contracts_dir
    contracts_dir="${CONTRACTS_DIR:-$SPEC_DIR/contracts}"
    local contract_file="$contracts_dir/${feature_id}.yaml"

    if [[ ! -f "$contract_file" ]]; then
        echo -e "${RED}Contract not found: $contract_file${NC}"
        return 1
    fi

    _AG_CONTRACT_FILE="$contract_file" \
    _AG_AC_ID="${ac_id:-}" \
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import os, sys
from pathlib import Path
from contracts import load_contract, save_contract

contract = load_contract(Path(os.environ['_AG_CONTRACT_FILE']))
target_ac = os.environ.get('_AG_AC_ID', '')

unshipped = [a for a in contract.assertions if a.status != 'shipped']

if not unshipped:
    print('All assertions are already shipped.')
    sys.exit(0)

if target_ac:
    found = [a for a in unshipped if a.id == target_ac]
    if not found:
        print(f'{target_ac} not found or already shipped.')
        ids = ', '.join(a.id for a in unshipped)
        print(f'Unshipped: {ids}')
        sys.exit(1)
    promoted = found
else:
    promoted = unshipped

# Capture old statuses before mutating
old_statuses = {a.id: a.status for a in promoted}
for a in promoted:
    a.status = 'shipped'
    print(f'  ✓ {a.id}: {old_statuses[a.id]} → shipped')

save_contract(contract)
print(f'\nPromoted {len(promoted)} assertion(s) in {contract.id}')
print(f'Run: ag contract check {contract.id}  to verify')
"
    return $?
}
