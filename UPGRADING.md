# Upgrading the Agentic Framework

**Purpose**: Guide for upgrading an existing project to a newer version of the Agentic Framework.

## Quick Upgrade (Recommended)

**For most upgrades (patch & minor versions):**

```bash
# 1. Check your current version
cat STACK.md | grep "Version:"  # e.g., "Version: 0.1.0"

# 2. Download latest release
curl -L https://github.com/YOUR_USERNAME/agentic-framework/archive/refs/tags/v0.2.0.tar.gz | tar xz

# 3. Run upgrade tool (this will backup and update)
bash agentic-framework-0.2.0/agentic/tools/upgrade.sh

# 4. Clean up
rm -rf agentic-framework-0.2.0
```

**The upgrade tool will:**
- Check your current version
- Backup your existing `agentic/` folder
- Replace framework files (preserving your project files)
- Update version in `STACK.md`
- Run compatibility checks
- Report any manual steps needed

## Manual Upgrade (Advanced)

If you prefer manual control or the upgrade tool isn't available:

### Step 1: Backup

```bash
# Backup your entire agentic folder
cp -r agentic agentic-backup-$(date +%Y%m%d)

# Backup your project specs and docs (if modified)
cp -r spec spec-backup-$(date +%Y%m%d)
cp -r docs docs-backup-$(date +%Y%m%d)
```

### Step 2: Download New Version

```bash
# Download latest release
curl -L https://github.com/YOUR_USERNAME/agentic-framework/archive/refs/tags/v0.2.0.tar.gz | tar xz
```

### Step 3: Identify What to Replace

**Always replace** (framework internals):
- `agentic/workflows/`
- `agentic/quality/`
- `agentic/agents/`
- `agentic/tools/` (scripts only, not their output)
- `agentic/init/` (templates only)
- `agentic/spec/` (templates only)
- `agentic/support/`
- `agentic/README.md`
- `agentic/START_HERE.md`
- `agentic/FRAMEWORK_MAP.md`

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
# Remove old framework internals
rm -rf agentic/workflows agentic/quality agentic/agents agentic/tools agentic/init agentic/spec agentic/support

# Copy new framework internals
cp -r agentic-framework-0.2.0/agentic/workflows agentic/
cp -r agentic-framework-0.2.0/agentic/quality agentic/
cp -r agentic-framework-0.2.0/agentic/agents agentic/
cp -r agentic-framework-0.2.0/agentic/tools agentic/
cp -r agentic-framework-0.2.0/agentic/init agentic/
cp -r agentic-framework-0.2.0/agentic/spec agentic/
cp -r agentic-framework-0.2.0/agentic/support agentic/

# Update framework docs
cp agentic-framework-0.2.0/agentic/README.md agentic/
cp agentic-framework-0.2.0/agentic/START_HERE.md agentic/
cp agentic-framework-0.2.0/agentic/FRAMEWORK_MAP.md agentic/

# Clean up
rm -rf agentic-framework-0.2.0
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
bash agentic/tools/doctor.sh

# Check spec format (if spec validation is enabled)
python3 agentic/tools/validate_specs.py

# Verify quality checks (if configured)
bash quality_checks.sh --pre-commit
```

### Step 7: Review Breaking Changes

Check `CHANGELOG.md` in the new version for breaking changes:

```bash
# Read CHANGELOG for your upgrade path
# Example: 0.1.0 → 0.2.0
curl -s https://raw.githubusercontent.com/YOUR_USERNAME/agentic-framework/v0.2.0/CHANGELOG.md | less
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
   git checkout -b upgrade-framework-v2
   ```
3. **Run upgrade tool** (or manual upgrade)
4. **Follow migration steps** from the guide
5. **Update custom workflows** (if any)
6. **Run full test suite**
7. **Verify agents work correctly**
8. **Merge when confident**

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
- Framework workflows (`agentic/workflows/`)
- Framework quality guides (`agentic/quality/`)
- Framework tools (`agentic/tools/`)
- Framework templates (`agentic/init/`, `agentic/spec/`)
- Framework agent guidelines (`agentic/agents/`)

## Troubleshooting

### Issue: Upgrade tool fails

**Solution**: Use manual upgrade process (see above)

### Issue: doctor.sh reports errors after upgrade

**Possible causes**:
1. **New required files**: Check CHANGELOG for new required files, run scaffold to add them
2. **Spec format changes**: Run `python3 agentic/tools/validate_specs.py` and fix issues
3. **Custom modifications**: Restore from backup, merge changes carefully

### Issue: Agents behave differently after upgrade

**Possible causes**:
1. **Agent guidelines changed**: Review `agentic/agents/shared/agent_operating_guidelines.md` for changes
2. **Workflow changes**: Check if your workflow (TDD, dev loop) was updated
3. **Quality standards updated**: Review `agentic/quality/programming_standards.md` and `agentic/quality/test_strategy.md`

**Solution**: Read CHANGELOG, review new documentation, update your understanding

### Issue: Quality checks fail after upgrade

**Possible causes**:
1. **New checks added**: Review `agentic/workflows/continuous_quality_validation.md`
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
curl -s https://api.github.com/repos/YOUR_USERNAME/agentic-framework/releases/latest | grep '"tag_name"'

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
# 1. Restore from backup
rm -rf agentic
mv agentic-backup-YYYYMMDD agentic

# 2. Revert STACK.md version field (if changed)
git checkout HEAD -- STACK.md

# 3. Test that everything works
bash agentic/tools/doctor.sh

# 4. Report issue to framework maintainers
```

## Future: Automated Upgrades

**Planned features** (not yet implemented):
- `agentic/tools/check_updates.sh` - Check for new versions
- `agentic/tools/upgrade.sh --dry-run` - Preview changes
- `agentic/tools/upgrade.sh --auto` - Fully automated upgrade
- GitHub Actions integration for upgrade notifications
- Automatic backup and rollback on failure

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

- **Framework docs**: `agentic/START_HERE.md`
- **CHANGELOG**: See release notes on GitHub
- **Issue tracker**: Report problems or ask questions

---

**Remember**: The framework is designed to be **minimally invasive**. Most upgrades are smooth and non-breaking. When in doubt, test in a branch first!

