# Acceptance Criteria

## Current Format: YAML Contracts (v0.73+)

The primary specification format is **YAML contracts** in `spec/contracts/F-####.yaml`.

```bash
ag contract create F-0001 "Feature Name"   # Create new contract
ag contract check F-0001                    # Verify assertions
ag contract list                            # List all contracts
ag migrate-specs                            # Convert markdown ACs to contracts
```

See `.agentic/lib/templates/contract.template.yaml` for the contract template.

## Legacy Format: Markdown Acceptance Criteria

Older projects may have markdown files (`F-####.md`) in this directory with sections for Behavior, Acceptance Criteria, and Verification. These are still recognized by framework tools but new features should use YAML contracts.

To migrate existing markdown ACs to contracts: `ag migrate-specs`

## Convention
- One contract per feature: `spec/contracts/F-####.yaml`
- Link from `spec/FEATURES.md` to the contract file
- Each contract has machine-verifiable assertions with test links
