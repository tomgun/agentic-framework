# Upgrading the Agentic Framework

**Purpose**: Guide for upgrading an existing project to a newer version of the Agentic Framework.

## Quick Upgrade (Recommended)

**For most upgrades (patch & minor versions):**

```bash
# 1. Check your current version (from your project directory)
cd /path/to/your-project
cat STACK.md | grep "Version:"  # e.g., "Version: 0.1.0"

# 2. Download and extract new framework (in a temp location)
cd /tmp
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.9.6.tar.gz | tar xz

# 3. Run the NEW upgrade tool, pointing it to your project
bash agentic-framework-0.9.4/.agentic/tools/upgrade.sh /path/to/your-project

# 4. Clean up
rm -rf agentic-framework-0.9.4
```

**Why run the script from the NEW framework?**
- ✅ Uses the latest upgrade logic (bug fixes, improvements)
- ✅ Knows about any new files or structure changes
- ✅ Can handle breaking changes intelligently
- ✅ Your old upgrade script might have bugs that are already fixed

**The upgrade tool will:**
- Check your current version
- Backup your existing `.agentic/` folder (timestamped)
- Replace all 14 framework directories and 8 root files
- Auto-migrate spec formats (`upgrade_spec_format.py`)
- Update version in `STACK.md` and `.agentic/VERSION`
- Run compatibility checks
- **Create `.agentic/.upgrade_pending` marker** for your AI agent
- Report any manual steps needed

**After upgrade, your AI agent will:**
- Detect the `.upgrade_pending` marker at session start
- Review new workflows and breaking changes
- Validate your specs against new format
- **Ask about new features** (e.g., sub-agent setup, multi-agent pipeline)
- Delete the marker when done

## Manual Upgrade (Advanced)

If you prefer manual control or the upgrade tool isn't available:

### Step 1: Backup

```bash
# Backup your entire .agentic folder
cp -r .agentic .agentic-backup-$(date +%Y%m%d)

# Backup your project specs and docs (if modified)
cp -r spec spec-backup-$(date +%Y%m%d)
cp -r docs docs-backup-$(date +%Y%m%d)
```

### Step 2: Download New Version

```bash
# Download latest release (to a temporary location, not your project)
cd /tmp  # Or any temp directory
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.9.6.tar.gz | tar xz
```

### Step 3: Identify What to Replace

**Always replace** (framework internals - 14 directories):
- `.agentic/workflows/`
- `.agentic/quality/`
- `.agentic/quality_profiles/`
- `.agentic/agents/`
- `.agentic/tools/`
- `.agentic/init/`
- `.agentic/spec/` (templates only, not your project's `spec/`)
- `.agentic/support/`
- `.agentic/checklists/`
- `.agentic/claude-hooks/`
- `.agentic/hooks/`
- `.agentic/prompts/`
- `.agentic/schemas/`
- `.agentic/token_efficiency/`

**Always replace** (8 root files):
- `.agentic/README.md`
- `.agentic/START_HERE.md`
- `.agentic/FRAMEWORK_MAP.md`
- `.agentic/MANUAL_OPERATIONS.md`
- `.agentic/DIRECT_EDITING.md`
- `.agentic/DEVELOPER_GUIDE.md`
- `.agentic/FRAMEWORK_DEVELOPMENT.md`
- `.agentic/PRINCIPLES.md`

**Never replace** (your project data):
- `STACK.md` (update version field only)
- `STATUS.md`
- `CONTEXT_PACK.md`
- `JOURNAL.md`
- `HUMAN_NEEDED.md`
- `spec/` (your specs, not templates)
- `docs/` (your docs)
- Any custom scripts you've added

**Maybe replace** (check changes):
- `quality_checks.sh` (if you customized it, merge changes)
- `.context7.yml` (if you customized it, merge changes)

### Step 4: Replace Framework Files

```bash
# From your project directory
cd /path/to/your-project
NEW_FW="/tmp/agentic-framework-0.9.4"

# Remove old framework internals (all 14 directories)
rm -rf .agentic/workflows .agentic/quality .agentic/quality_profiles \
       .agentic/agents .agentic/tools .agentic/init .agentic/spec \
       .agentic/support .agentic/checklists .agentic/claude-hooks \
       .agentic/hooks .agentic/prompts .agentic/schemas .agentic/token_efficiency

# Copy new framework internals
for dir in workflows quality quality_profiles agents tools init spec support \
           checklists claude-hooks hooks prompts schemas token_efficiency; do
  cp -r "$NEW_FW/.agentic/$dir" .agentic/
done

# Update framework docs (all 8 files)
for file in README.md START_HERE.md FRAMEWORK_MAP.md MANUAL_OPERATIONS.md \
            DIRECT_EDITING.md DEVELOPER_GUIDE.md FRAMEWORK_DEVELOPMENT.md PRINCIPLES.md; do
  cp "$NEW_FW/.agentic/$file" .agentic/
done

# Update VERSION
cp "$NEW_FW/VERSION" .agentic/VERSION

# Clean up
rm -rf "$NEW_FW"
```

### Step 5: Update Version in STACK.md

```bash
# Edit STACK.md and update the framework version field
# Change:
#   Version: 0.1.0
# To:
#   Version: 0.2.0
```

### Step 6: Run Compatibility Checks

```bash
# Verify structure
bash .agentic/tools/doctor.sh

# Check spec format (if spec validation is enabled)
python3 .agentic/tools/validate_specs.py

# Verify quality checks (if configured)
bash quality_checks.sh --pre-commit
```

### Step 7: Review Breaking Changes

Check `CHANGELOG.md` in the new version for breaking changes:

```bash
# Read CHANGELOG for your upgrade path
# Example: 0.1.0 → 0.2.0
curl -s https://raw.githubusercontent.com/tomgun/agentic-framework/v0.2.0/CHANGELOG.md | less
```

## Upgrade Strategies by Version Type

### Patch Upgrades (0.1.0 → 0.1.1)

**Risk**: Very low  
**Breaking changes**: None  
**Recommended**: Upgrade immediately

**Process**:
1. Run quick upgrade tool
2. Test basic operations
3. Done!

**Time**: 5-10 minutes

### Minor Upgrades (0.1.0 → 0.2.0)

**Risk**: Low  
**Breaking changes**: Minimal (if any, will be documented)  
**Recommended**: Upgrade within 1-2 weeks

**Process**:
1. Read CHANGELOG for new features
2. Run quick upgrade tool
3. Test your workflow
4. Optionally adopt new features

**Time**: 15-30 minutes

### Major Upgrades (0.x → 1.x or 1.x → 2.x)

**Risk**: Medium to High  
**Breaking changes**: Likely (documented in migration guide)  
**Recommended**: Plan upgrade, test thoroughly

**Process**:
1. **Read migration guide** (e.g., `docs/migrations/v1-to-v2.md`)
2. **Test in a branch first**:
   ```bash
   cd /path/to/your-project
   git checkout -b upgrade-framework-v2
   ```
3. **Download new framework**:
   ```bash
   cd /tmp
   curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/vX.0.0.tar.gz | tar xz
   ```
4. **Run the NEW upgrade tool**:
   ```bash
   bash /tmp/agentic-framework-X.0.0/.agentic/tools/upgrade.sh /path/to/your-project
   ```
5. **Follow migration steps** from the guide (may require manual fixes)
6. **Update custom workflows** (if any)
7. **Run full test suite**
8. **Verify agents work correctly**
9. **Merge when confident**

**Time**: 1-4 hours (depending on customizations)

## Version Compatibility Matrix

| Your Version | Target Version | Upgrade Path | Breaking Changes |
|:-------------|:---------------|:-------------|:-----------------|
| 0.1.0        | 0.1.x          | Direct       | None             |
| 0.1.0        | 0.2.0          | Direct       | Minimal          |
| 0.1.0        | 1.0.0          | See guide    | Yes              |
| 0.x          | 1.0.0          | See guide    | Yes              |
| 1.x          | 2.0.0          | See guide    | Yes              |

## What Gets Preserved During Upgrade?

✅ **Always preserved:**
- Your specs (`spec/FEATURES.md`, `spec/PRD.md`, etc.)
- Your documentation (`docs/`)
- Your project status (`STATUS.md`, `JOURNAL.md`)
- Your stack configuration (`STACK.md` - version field updated only)
- Your custom quality checks (if you merged changes properly)
- Your codebase (obviously!)

❌ **Never preserved (replaced by framework):**
- Framework workflows (`.agentic/workflows/`)
- Framework quality guides (`.agentic/quality/`)
- Framework tools (`.agentic/tools/`)
- Framework templates (`.agentic/init/`, `.agentic/spec/`)
- Framework agent guidelines (`.agentic/agents/`)

## Troubleshooting

### Issue: Upgrade tool fails

**Solution**: Use manual upgrade process (see above)

### Issue: doctor.sh reports errors after upgrade

**Possible causes**:
1. **New required files**: Check CHANGELOG for new required files, run scaffold to add them
2. **Spec format changes**: Run `python3 .agentic/tools/validate_specs.py` and fix issues
3. **Custom modifications**: Restore from backup, merge changes carefully

### Issue: Agents behave differently after upgrade

**Possible causes**:
1. **Agent guidelines changed**: Review `.agentic/agents/shared/agent_operating_guidelines.md` for changes
2. **Workflow changes**: Check if your workflow (TDD, dev loop) was updated
3. **Quality standards updated**: Review `.agentic/quality/programming_standards.md` and `.agentic/quality/test_strategy.md`

**Solution**: Read CHANGELOG, review new documentation, update your understanding

### Issue: Quality checks fail after upgrade

**Possible causes**:
1. **New checks added**: Review `.agentic/workflows/continuous_quality_validation.md`
2. **Custom profile outdated**: Update your `quality_checks.sh` based on new template

**Solution**: Regenerate quality profile or merge changes manually

## Staying Up to Date

### Option 1: Watch for Releases

**On GitHub**:
1. Go to framework repository
2. Click "Watch" → "Custom" → "Releases"
3. Get notified when new versions are released

### Option 2: Check Periodically

```bash
# Check latest release
curl -s https://api.github.com/repos/tomgun/agentic-framework/releases/latest | grep '"tag_name"'

# Compare to your version
cat STACK.md | grep "Version:"
```

### Option 3: Tell Your Agent

> "Check if there's a newer version of the agentic framework available and tell me if I should upgrade."

The agent will:
1. Check your `STACK.md` for current version
2. Check GitHub for latest release
3. Summarize changes and recommend upgrade timing

## When NOT to Upgrade

**Wait to upgrade if:**
- You're in the middle of a critical feature (finish first)
- You have an imminent deadline (upgrade after)
- The upgrade is a major version and you haven't reviewed the migration guide
- Your project has extensive customizations (test in a branch first)

**Safe times to upgrade:**
- Between features
- During retrospective sessions
- After a major milestone
- During planned maintenance windows

## Rollback

If upgrade causes issues:

```bash
# 1. Restore from backup (backup created by upgrade.sh)
rm -rf .agentic
mv agentic-backup-YYYYMMDD-HHMMSS .agentic

# 2. Revert STACK.md version field (if changed)
git checkout HEAD -- STACK.md

# 3. Test that everything works
bash .agentic/tools/doctor.sh

# 4. Report issue to framework maintainers
```

## Available Upgrade Features

**Implemented:**
- ✅ `.agentic/tools/upgrade.sh` - Full upgrade with backup
- ✅ `DRY_RUN=yes upgrade.sh` - Preview changes without applying
- ✅ `.agentic/tools/version_check.sh` - Check version mismatch
- ✅ Automatic backup (timestamped folder)
- ✅ Auto-migrate spec formats
- ✅ `.upgrade_pending` marker for agent awareness

**Planned** (not yet implemented):
- GitHub Actions integration for upgrade notifications
- Automatic rollback on failure

## Migration Guides (for Major Versions)

**When a major version is released**, a dedicated migration guide will be created:

- `docs/migrations/v0-to-v1.md`
- `docs/migrations/v1-to-v2.md`

These guides will contain:
- Detailed list of breaking changes
- Step-by-step migration instructions
- Before/after examples
- Automated migration scripts (if available)
- FAQ and troubleshooting

## Questions?

- **Framework docs**: `.agentic/START_HERE.md`
- **CHANGELOG**: See release notes on GitHub
- **Issue tracker**: Report problems or ask questions

---

**Remember**: The framework is designed to be **minimally invasive**. Most upgrades are smooth and non-breaking. When in doubt, test in a branch first!

