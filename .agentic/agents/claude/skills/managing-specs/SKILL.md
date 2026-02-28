---
name: managing-specs
description: >
  Feature specification lifecycle management: create specs, update status,
  track features. Use when user says "update spec", "mark shipped", "feature
  status", "ag specs", "add feature to FEATURES.md", "track this feature".
  Do NOT use for: writing acceptance criteria for implementation (use
  implementing-features), planning architecture (use planning-features).
compatibility: "Requires Claude Code with file access and ag commands."
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Managing Specs

Feature specification lifecycle: create, track, and update feature status.

## Instructions

### Step 1: Identify the Action

Determine what spec operation is needed:
- **Create**: New feature entry in FEATURES.md + acceptance criteria
- **Update status**: Change feature status (planned → in_progress → shipped)
- **Update content**: Modify description, dependencies, or acceptance criteria
- **Audit**: Check for drift between specs and implementation

### Step 2: Use Token-Efficient Scripts

For status updates:
```bash
bash .agentic/tools/feature.sh F-XXXX status shipped
```

For creating new features, add an entry to `spec/FEATURES.md` following the existing format, then create `spec/acceptance/F-XXXX.md`.

### Step 3: Maintain Consistency

After any spec change, verify:
- Feature status in FEATURES.md matches reality
- Acceptance criteria file exists for active features
- Dependencies are accurate
- VERSION bump if specs changed significantly

## Examples

**Example 1: Mark feature as shipped**
User says: "F-0125 is done, mark it shipped"
Steps taken:
1. Run `bash .agentic/tools/feature.sh F-0125 status shipped`
2. Verify acceptance criteria are all met
3. Update STATUS.md
Result: Feature status updated to shipped.

**Example 2: Create new feature spec**
User says: "Let's track the caching feature"
Steps taken:
1. Find next available F-XXXX number in FEATURES.md
2. Add feature entry with description, status: planned, priority, complexity
3. Create spec/acceptance/F-XXXX.md with criteria
Result: Feature tracked and ready for planning.

**Example 3: Audit specs**
User says: "ag specs" or "check spec status"
Steps taken:
1. Read FEATURES.md, list features by status
2. Check for in_progress features without WIP
3. Check for shipped features without acceptance validation
Result: Report of spec health with suggested actions.

## Troubleshooting

**Feature ID conflict**
Cause: Two features with same F-XXXX number.
Solution: Check FEATURES.md for the latest number, use the next available.

**Specs out of sync with code**
Cause: Implementation diverged from spec without updates.
Solution: Read current implementation, update acceptance criteria to match reality, note the divergence in JOURNAL.md.
