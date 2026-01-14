---
command: /verify
description: Run verification gates - the human helps enforce quality
---

The user wants to verify the current state. This is how humans help the framework enforce quality.

**Run verification immediately:**

```bash
bash .agentic/tools/doctor.sh --full
```

**Based on results:**

1. **If all checks pass**: Report "✓ All gates passed" and continue work

2. **If issues found**:
   - List each issue clearly
   - Explain what needs to be fixed
   - Offer to fix automatically where possible
   - For issues requiring human decision, add to HUMAN_NEEDED.md

3. **If suggestions shown**:
   - Explain each suggestion
   - Ask if user wants to address them now or later

**After verification, summarize:**
- Current phase (start/planning/implement/complete/commit)
- What's working
- What needs attention
- Recommended next action

**Remember**: The user running `/verify` is actively helping maintain quality. Acknowledge this partnership.
