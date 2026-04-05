#!/usr/bin/env bash
# commands/persona.sh — Persona management commands
# Sourced by ag.sh — do NOT execute directly.
# Depends on: SCRIPT_DIR, ROOT_DIR, SPEC_DIR, color codes

cmd_persona() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        list)       _persona_list ;;
        check)      _persona_check ;;
        migrate)    _persona_migrate "$@" ;;
        coverage)   _persona_coverage "$@" ;;
        generate)   _persona_generate "$@" ;;
        help|--help|-h) _persona_help ;;
        *)
            echo -e "${RED}Unknown persona subcommand: $subcmd${NC}"
            _persona_help
            return 1
            ;;
    esac
}

_persona_help() {
    echo -e "${BOLD}ag persona${NC} — Persona & platform management"
    echo ""
    echo "  list                 List defined personas and their platforms"
    echo "  check                Validate personas.yaml and refs in contracts"
    echo "  migrate              Check for capability changes needing migration"
    echo "  coverage [--by-persona|--by-platform|--by-capability]"
    echo "                       Coverage analysis by persona dimension"
    echo "  generate [--persona ID] [--output-contract F-XXXX] [--dry-run]"
    echo "                       Generate draft assertions from persona capabilities"
    echo ""
    echo "Personas defined in: ${SPEC_DIR:-spec}/personas.yaml"
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

_persona_list() {
    local spec_dir="${SPEC_DIR:-.agentic/spec}"
    local personas_file="$spec_dir/personas.yaml"

    if [[ ! -f "$personas_file" ]]; then
        echo -e "${YELLOW}No personas.yaml found at $personas_file${NC}"
        echo "Create one with: cp .agentic/lib/templates/personas.template.yaml $personas_file"
        return 1
    fi

    echo -e "${BOLD}Personas${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
from pathlib import Path
from contracts import load_personas

pf = load_personas(Path('$spec_dir'))
if not pf:
    print('  No personas found')
    exit(0)

print(f'  Protection: {pf.protection}')
if pf.version:
    print(f'  Version: {pf.version}')
print()

for p in pf.personas:
    platforms = ', '.join(p.platforms) if p.platforms else 'none'
    print(f'  {p.id}')
    print(f'    Name: {p.name}')
    if p.description:
        print(f'    Description: {p.description}')
    print(f'    Platforms: {platforms}')
    if p.goals:
        print(f'    Goals:')
        for g in p.goals:
            print(f'      - {g}')
    if p.capabilities:
        print(f'    Capabilities ({len(p.capabilities)}):')
        for c in p.capabilities:
            print(f'      - {c}')
    print()

if pf.platforms:
    print('  Platforms:')
    for pl in pf.platforms:
        desc = f' — {pl.description}' if pl.description else ''
        print(f'    {pl.id}: {pl.name}{desc}')
    print()

print(f'{len(pf.personas)} persona(s), {len(pf.platforms)} platform(s)')
if pf.migrations:
    print(f'{len(pf.migrations)} migration(s)')
"
}

_persona_check() {
    local spec_dir="${SPEC_DIR:-.agentic/spec}"
    local contracts_dir="${CONTRACTS_DIR:-$spec_dir/contracts}"
    local personas_file="$spec_dir/personas.yaml"

    if [[ ! -f "$personas_file" ]]; then
        echo -e "${YELLOW}No personas.yaml — nothing to check${NC}"
        return 0
    fi

    echo -e "${BOLD}Persona Reference Check${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import sys
from pathlib import Path
from contracts import load_personas, load_all_contracts, validate_persona_refs

spec_dir = Path('$spec_dir')
contracts_dir = Path('$contracts_dir')

pf = load_personas(spec_dir)
if not pf:
    print('  No personas.yaml found')
    sys.exit(0)

contracts = load_all_contracts(contracts_dir)
total_errors = 0

for c in contracts:
    # Only check contracts that reference personas/platforms
    if not c.personas and not c.platforms and not any(a.personas or a.platforms or a.capability_ref for a in c.assertions):
        continue
    errors = validate_persona_refs(c, pf)
    if errors:
        total_errors += len(errors)
        print(f'  {c.id} ({c.name}):')
        for e in errors:
            print(f'    ✗ {e}')
        print()

# Check for orphaned capability_refs (capability removed from persona)
all_slugs = set()
for p in pf.personas:
    for cap in p.capabilities:
        all_slugs.add(p.capability_slug(cap))

orphaned = []
for c in contracts:
    for a in c.assertions:
        if a.capability_ref and a.capability_ref not in all_slugs:
            orphaned.append(f'{c.id}:{a.id} → {a.capability_ref}')

if orphaned:
    print('  Orphaned capability_refs:')
    for o in orphaned:
        print(f'    ✗ {o}')
    total_errors += len(orphaned)
    print()

# Platform consistency: assertion platforms should be subset of persona platforms
for c in contracts:
    for a in c.assertions:
        if a.personas and a.platforms:
            for pid in a.personas:
                persona = pf.get_persona(pid)
                if persona and persona.platforms:
                    extra = set(a.platforms) - set(persona.platforms)
                    if extra:
                        msg = f'{c.id}:{a.id} targets platforms {extra} not in persona {pid}\'s platforms {persona.platforms}'
                        print(f'    ⚠ {msg}')
                        total_errors += 1

if total_errors == 0:
    print('  ✓ All persona references valid')
else:
    print(f'{total_errors} error(s) found')
    sys.exit(1)
"
    return $?
}

_persona_migrate() {
    local spec_dir="${SPEC_DIR:-.agentic/spec}"
    local contracts_dir="${CONTRACTS_DIR:-$spec_dir/contracts}"

    echo -e "${BOLD}Persona Migration Check${NC}"
    echo ""
    echo "Checking for capability changes that may affect contracts..."
    echo ""

    # This is primarily a reporting tool — actual migration is done by the agent
    # after reviewing the report
    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import sys
from pathlib import Path
from contracts import load_personas, load_all_contracts

spec_dir = Path('$spec_dir')
contracts_dir = Path('$contracts_dir')

pf = load_personas(spec_dir)
if not pf:
    print('  No personas.yaml found')
    sys.exit(0)

contracts = load_all_contracts(contracts_dir)

# Build set of all capability_refs in contracts
refs_in_contracts = {}
for c in contracts:
    for a in c.assertions:
        if a.capability_ref:
            refs_in_contracts.setdefault(a.capability_ref, []).append(f'{c.id}:{a.id}')

# Build set of all current capability slugs
current_slugs = {}
for p in pf.personas:
    for cap in p.capabilities:
        slug = p.capability_slug(cap)
        current_slugs[slug] = (p.id, cap)

# Find orphaned refs (capability removed or renamed)
orphaned = {ref: locs for ref, locs in refs_in_contracts.items() if ref not in current_slugs}
# Find uncovered capabilities (no assertion yet)
uncovered = {slug: info for slug, info in current_slugs.items() if slug not in refs_in_contracts}

if orphaned:
    print('  Orphaned capability_refs (capability removed/renamed):')
    for ref, locs in orphaned.items():
        print(f'    {ref}')
        for loc in locs:
            print(f'      referenced by: {loc}')
    print()

if uncovered:
    print('  Uncovered capabilities (no assertion generated yet):')
    for slug, (pid, cap) in uncovered.items():
        print(f'    {pid}: {cap}')
    print()

if pf.protection == 'contract' and not pf.migrations:
    print('  ⚠ Protection is \"contract\" but no migrations recorded')
    print()

if not orphaned and not uncovered:
    print('  ✓ All capabilities are in sync with contract assertions')
else:
    total = len(orphaned) + len(uncovered)
    print(f'{total} item(s) need attention')
    if orphaned:
        print('  Run the agent to update orphaned capability_refs')
    if uncovered:
        print('  Run: ag persona generate --dry-run')
"
}

_persona_coverage() {
    local spec_dir="${SPEC_DIR:-.agentic/spec}"
    local contracts_dir="${CONTRACTS_DIR:-$spec_dir/contracts}"
    local mode="all"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --by-persona)     mode="persona"; shift ;;
            --by-platform)    mode="platform"; shift ;;
            --by-capability)  mode="capability"; shift ;;
            *) shift ;;
        esac
    done

    echo -e "${BOLD}Persona Coverage Report${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 -c "
import json
from pathlib import Path
from contracts import persona_coverage_report

report = persona_coverage_report(Path('$contracts_dir'), Path('$spec_dir'))

if 'error' in report:
    print(f'  {report[\"error\"]}')
    exit(1)

mode = '$mode'

if mode in ('all', 'persona'):
    print('  By Persona:')
    for pid, info in report['personas'].items():
        bar = '█' * int(info['pct'] / 5) + '░' * (20 - int(info['pct'] / 5))
        print(f'    {pid:<30} {info[\"covered\"]}/{info[\"total\"]} ({info[\"pct\"]}%) {bar}')
    print()

if mode in ('all', 'platform'):
    print('  By Platform:')
    for plid, info in report['platforms'].items():
        bar = '█' * int(info['pct'] / 5) + '░' * (20 - int(info['pct'] / 5))
        print(f'    {plid:<30} {info[\"covered\"]}/{info[\"total\"]} ({info[\"pct\"]}%) {bar}')
    print()

if mode in ('all', 'capability'):
    print('  By Capability:')
    caps = report.get('capabilities', {})
    for slug, info in caps.items():
        status = '✓' if info['covered'] else '✗'
        refs = ', '.join(info['assertions'][:3]) if info['assertions'] else '(no assertion)'
        print(f'    {status} {info[\"persona\"]}: {info[\"capability\"]}')
        print(f'        → {refs}')
    print()
    summary = report.get('capability_summary', {})
    if summary:
        print(f'  Capability coverage: {summary[\"covered\"]}/{summary[\"total\"]} ({summary[\"pct\"]}%)')
"
}

_persona_generate() {
    local spec_dir="${SPEC_DIR:-.agentic/spec}"
    local contracts_dir="${CONTRACTS_DIR:-$spec_dir/contracts}"
    local extra_args=""

    while [[ $# -gt 0 ]]; do
        extra_args="$extra_args $1"
        shift
    done

    echo -e "${BOLD}Generate Assertions from Persona Capabilities${NC}"
    echo ""

    PYTHONPATH="$ROOT_DIR/.agentic/lib" python3 \
        "$ROOT_DIR/.agentic/lib/tools/generate_from_personas.py" \
        "$spec_dir" \
        --contracts-dir "$contracts_dir" \
        $extra_args
}
