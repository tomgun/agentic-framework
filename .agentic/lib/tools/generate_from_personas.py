#!/usr/bin/env python3
"""
generate_from_personas.py — Generate draft contract assertions from persona capabilities.

Usage:
    python3 generate_from_personas.py <spec_dir> [--persona <id>] [--contracts-dir <dir>] [--dry-run]

Reads spec/personas.yaml and generates draft assertions for each persona capability.
Outputs new or updated contract YAML files with draft: true assertions.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Add lib to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from contracts import (
    Contract, Assertion, PersonaDef, PersonasFile,
    load_personas, load_all_contracts, save_contract,
    get_contract_by_id,
)


def capability_to_assertion_text(persona: PersonaDef, capability: str) -> str:
    """Convert a persona capability into assertion text."""
    return f"{persona.name} can {capability[0].lower()}{capability[1:]}"


def capability_to_ac_id(existing_ids: set[str], start: int = 1) -> str:
    """Generate the next available AC-XXX id."""
    for n in range(start, 10000):
        ac_id = f"AC-{n:03d}"
        if ac_id not in existing_ids:
            return ac_id
    raise ValueError("Cannot generate AC id: all AC-001 through AC-9999 are taken")


def generate_assertions_for_persona(
    persona: PersonaDef,
    existing_contracts: list[Contract],
) -> list[tuple[str, Assertion]]:
    """Generate draft assertions for a persona's capabilities.

    Returns list of (capability_ref, Assertion) tuples.
    Skips capabilities already covered by existing assertions.
    """
    # Collect all existing capability_refs
    existing_refs: set[str] = set()
    for c in existing_contracts:
        for a in c.assertions:
            if a.capability_ref:
                existing_refs.add(a.capability_ref)

    new_assertions: list[tuple[str, Assertion]] = []
    for cap in persona.capabilities:
        slug = persona.capability_slug(cap)
        if slug in existing_refs:
            continue  # Already covered

        assertion = Assertion(
            id="AC-000",  # Placeholder — assigned when added to a contract
            text=capability_to_assertion_text(persona, cap),
            type="behavioral",
            draft=True,
            personas=[persona.id],
            platforms=list(persona.platforms),
            capability_ref=slug,
        )
        new_assertions.append((slug, assertion))

    return new_assertions


def apply_to_contract(
    contract: Contract,
    assertions: list[tuple[str, Assertion]],
) -> int:
    """Add generated assertions to an existing contract. Returns count added."""
    existing_ids = {a.id for a in contract.assertions}
    existing_refs = {a.capability_ref for a in contract.assertions if a.capability_ref}

    added = 0
    for slug, assertion in assertions:
        if slug in existing_refs:
            continue
        ac_id = capability_to_ac_id(existing_ids)
        existing_ids.add(ac_id)
        assertion.id = ac_id
        contract.assertions.append(assertion)
        added += 1

    return added


def main():
    parser = argparse.ArgumentParser(
        description="Generate draft contract assertions from persona capabilities"
    )
    parser.add_argument("spec_dir", help="Path to spec/ directory")
    parser.add_argument("--persona", help="Generate for a specific persona ID only")
    parser.add_argument("--contracts-dir", help="Contracts directory (default: spec_dir/contracts)")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be generated without writing")
    parser.add_argument("--output-contract", help="Target contract ID to add assertions to (e.g., F-100)")
    args = parser.parse_args()

    spec_dir = Path(args.spec_dir)
    contracts_dir = Path(args.contracts_dir) if args.contracts_dir else spec_dir / "contracts"

    personas_file = load_personas(spec_dir)
    if not personas_file:
        print("ERROR: No personas.yaml found in", spec_dir, file=sys.stderr)
        sys.exit(1)

    existing_contracts = load_all_contracts(contracts_dir)

    # Filter to specific persona if requested
    personas_to_process = personas_file.personas
    if args.persona:
        persona = personas_file.get_persona(args.persona)
        if not persona:
            print(f"ERROR: Persona '{args.persona}' not found", file=sys.stderr)
            sys.exit(1)
        personas_to_process = [persona]

    # Generate assertions
    all_generated: list[tuple[PersonaDef, list[tuple[str, Assertion]]]] = []
    total_new = 0
    for persona in personas_to_process:
        new_assertions = generate_assertions_for_persona(persona, existing_contracts)
        if new_assertions:
            all_generated.append((persona, new_assertions))
            total_new += len(new_assertions)

    if not total_new:
        print("All persona capabilities are already covered by existing assertions.")
        return

    # Output
    print(f"\nGenerated {total_new} draft assertion(s):\n")
    for persona, assertions in all_generated:
        print(f"  {persona.name} ({persona.id}):")
        for slug, a in assertions:
            platforms_str = f" [{', '.join(a.platforms)}]" if a.platforms else ""
            print(f"    - {a.text}{platforms_str}")
            print(f"      capability_ref: {slug}")
        print()

    if args.dry_run:
        print("[dry-run] No files written.")
        return

    # If a target contract is specified, add to it
    if args.output_contract:
        contract = get_contract_by_id(contracts_dir, args.output_contract)
        if not contract:
            print(f"ERROR: Contract '{args.output_contract}' not found", file=sys.stderr)
            sys.exit(1)

        all_assertions = []
        for _, assertions in all_generated:
            all_assertions.extend(assertions)

        added = apply_to_contract(contract, all_assertions)
        save_contract(contract)
        print(f"Added {added} draft assertion(s) to {contract.id}")
    else:
        # Print YAML for manual inclusion
        print("Add --output-contract <ID> to write to a specific contract,")
        print("or copy the assertions above into your contract files.")


if __name__ == "__main__":
    main()
