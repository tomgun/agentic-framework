# Create Spec Migration Prompt (Formal Mode)

I want to create a new spec migration for: **[brief description of change]**

Please follow the spec migration workflow:

1. **Create migration file:**
   ```bash
   bash .agentic/tools/migration.sh create "[Concise title of change]"
   ```
   This will generate `spec/migrations/XXX_[title].md` with the next ID.

2. **Fill in migration details:**
   - **Context**: Why is this change needed? What problem does it solve?
   - **Changes**: List atomic changes (e.g., "Added F-0010: User Login", "Updated NFR-0003: Performance")
   - **Dependencies**: What must exist before this change? What does this block?
   - **Acceptance Criteria**: How to verify this migration was applied correctly?
   - **Rollback Plan**: How to safely undo this change if needed?

3. **Update main spec files:**
   After creating the migration, update the current state documents:
   - `spec/FEATURES.md` (if adding/modifying features)
   - `spec/NFR.md` (if changing non-functional requirements)
   - `spec/PRD.md` (if changing product direction)
   - Other spec files as needed

4. **Keep both in sync:**
   - Migration file = historical record (what changed and why)
   - Main spec file = current state (what is true now)

5. **Update JOURNAL.md:**
   - Log the migration creation and rationale

6. **Commit together:**
   - Commit migration file + updated spec files + JOURNAL.md
   - Message format: `spec: [migration title]`

---

**When to use migrations:**
- Complex projects with many features
- When you need an audit trail of spec changes
- When multiple agents/humans are editing specs
- When `spec_migration_mode: enabled` in `STACK.md`

**When to skip migrations:**
- Simple, small projects (Discovery mode or Formal with few features)
- Quick, minor adjustments
- When reviewing overall feature status (read `FEATURES.md` directly)

---

**Reference:**
- See `.agentic/workflows/spec_migrations.md` for full details
- Migration template: `.agentic/spec/MIGRATION.template.md`

