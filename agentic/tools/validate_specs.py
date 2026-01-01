#!/usr/bin/env python3
"""
Validate spec files with YAML frontmatter against JSON schemas.

Single source of truth: All data in one .md file with frontmatter.
Automatic validation: Catches typos, wrong values, missing fields.
"""

import sys
import yaml
import json
from pathlib import Path
from typing import Any, Optional

try:
    import frontmatter
    from jsonschema import validate, ValidationError, Draft7Validator
except ImportError:
    print("ERROR: Missing dependencies. Install with:")
    print("  pip install python-frontmatter jsonschema pyyaml")
    sys.exit(1)


def load_schema(schema_path: Path) -> Optional[dict]:
    """Load JSON schema file."""
    if not schema_path.exists():
        return None
    
    with open(schema_path, 'r') as f:
        return json.load(f)


def validate_features_file(features_file: Path, schema: dict) -> list[str]:
    """Validate FEATURES.md frontmatter against schema."""
    errors = []
    
    if not features_file.exists():
        return errors
    
    # Parse frontmatter
    with open(features_file, 'r') as f:
        try:
            post = frontmatter.load(f)
        except yaml.YAMLError as e:
            return [f"YAML parsing error: {e}"]
    
    # Get features array
    features = post.metadata.get('features', [])
    
    if not features:
        # No frontmatter yet - this is OK, just warn
        return []
    
    # Validate each feature
    validator = Draft7Validator(schema)
    
    for idx, feature in enumerate(features):
        feature_id = feature.get('id', f'feature-{idx}')
        
        for error in validator.iter_errors(feature):
            # Format error nicely
            field_path = '.'.join(str(p) for p in error.path) if error.path else 'root'
            errors.append(f"{feature_id}: {field_path} - {error.message}")
    
    return errors


def validate_nfr_file(nfr_file: Path, schema: dict) -> list[str]:
    """Validate NFR.md frontmatter against schema."""
    errors = []
    
    if not nfr_file.exists():
        return errors
    
    with open(nfr_file, 'r') as f:
        try:
            post = frontmatter.load(f)
        except yaml.YAMLError as e:
            return [f"YAML parsing error: {e}"]
    
    nfrs = post.metadata.get('nfrs', [])
    
    if not nfrs:
        return []
    
    validator = Draft7Validator(schema)
    
    for idx, nfr in enumerate(nfrs):
        nfr_id = nfr.get('id', f'nfr-{idx}')
        
        for error in validator.iter_errors(nfr):
            field_path = '.'.join(str(p) for p in error.path) if error.path else 'root'
            errors.append(f"{nfr_id}: {field_path} - {error.message}")
    
    return errors


def main() -> int:
    """Main validation routine."""
    root = Path.cwd()
    schema_dir = root / "agentic" / "schemas"
    spec_dir = root / "spec"
    
    print("=== Spec Validation ===")
    print()
    
    all_errors = []
    
    # Validate FEATURES.md
    features_file = spec_dir / "FEATURES.md"
    feature_schema_file = schema_dir / "feature.schema.json"
    
    if features_file.exists():
        print("Validating spec/FEATURES.md...")
        
        if not feature_schema_file.exists():
            print("  ⚠️  No schema found (agentic/schemas/feature.schema.json)")
            print("     Skipping validation.")
        else:
            schema = load_schema(feature_schema_file)
            errors = validate_features_file(features_file, schema)
            
            if errors:
                print(f"  ❌ {len(errors)} error(s) found:")
                for error in errors:
                    print(f"     - {error}")
                    all_errors.append(error)
            else:
                print("  ✅ Valid")
    
    # Validate NFR.md
    nfr_file = spec_dir / "NFR.md"
    nfr_schema_file = schema_dir / "nfr.schema.json"
    
    if nfr_file.exists():
        print()
        print("Validating spec/NFR.md...")
        
        if not nfr_schema_file.exists():
            print("  ⚠️  No schema found (agentic/schemas/nfr.schema.json)")
            print("     Skipping validation.")
        else:
            schema = load_schema(nfr_schema_file)
            errors = validate_nfr_file(nfr_file, schema)
            
            if errors:
                print(f"  ❌ {len(errors)} error(s) found:")
                for error in errors:
                    print(f"     - {error}")
                    all_errors.append(error)
            else:
                print("  ✅ Valid")
    
    print()
    
    if all_errors:
        print(f"❌ Total errors: {len(all_errors)}")
        print()
        print("Fix errors in spec files and run again.")
        return 1
    else:
        print("✅ All specs valid!")
        return 0


if __name__ == "__main__":
    sys.exit(main())

