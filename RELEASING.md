# How to Create a Release

This guide explains how to create a new version release of the Agentic Framework.

## Pre-Release Checklist

1. **All changes committed and pushed**
   ```bash
   git status  # Should be clean
   ```

2. **Update VERSION file**
   ```bash
   echo "0.2.0" > VERSION
   ```

3. **Update CHANGELOG.md**
   - Add new `## [0.2.0] - YYYY-MM-DD` section
   - List all changes under Added/Changed/Fixed/Removed
   - Move items from `[Unreleased]` section

4. **Update STACK.template.md**
   - Change version number in template

5. **Commit version bump**
   ```bash
   git add VERSION CHANGELOG.md agentic/init/STACK.template.md
   git commit -m "chore: bump version to 0.2.0"
   git push origin main
   ```

## Create Release

### Option 1: GitHub UI (Recommended)

1. **Go to GitHub repository**
   - Navigate to: https://github.com/YOUR_USERNAME/agentic-framework

2. **Create new release**
   - Click "Releases" → "Draft a new release"
   - **Tag**: `v0.2.0` (must match VERSION file with `v` prefix)
   - **Target**: `main` branch
   - **Title**: `v0.2.0`
   - **Description**: Copy from CHANGELOG.md for this version
   - Check "Set as the latest release"
   - Click "Publish release"

3. **GitHub automatically creates:**
   - `agentic-framework-0.2.0.tar.gz` (source archive)
   - `agentic-framework-0.2.0.zip` (source archive)

### Option 2: GitHub CLI

```bash
# Create and push tag
git tag v0.2.0
git push origin v0.2.0

# Create release with gh CLI
gh release create v0.2.0 \
  --title "v0.2.0" \
  --notes-file RELEASE_NOTES.md \
  --latest
```

### Option 3: Git Tags Only

```bash
# Create annotated tag
git tag -a v0.2.0 -m "Release v0.2.0"

# Push tag to GitHub
git push origin v0.2.0

# Then manually create release on GitHub using this tag
```

## Version Numbering (Semantic Versioning)

```
MAJOR.MINOR.PATCH

0.1.0 → Initial beta release
0.2.0 → New features added (backward compatible)
0.2.1 → Bug fixes (backward compatible)
1.0.0 → First stable release
2.0.0 → Breaking changes (requires migration)
```

**When to increment:**
- **MAJOR (X.0.0)**: Breaking changes, incompatible with previous version
  - Example: Spec format changed, requires migration
  - Example: Tool renamed or removed
  - Example: Agent guidelines fundamentally changed
- **MINOR (0.X.0)**: New features, backward compatible
  - Example: New quality profile added
  - Example: New tool added
  - Example: New workflow document added
- **PATCH (0.0.X)**: Bug fixes, backward compatible
  - Example: Fix typo in docs
  - Example: Fix script error
  - Example: Improve example

## Post-Release

1. **Announce release**
   - Update README with latest version number
   - Update installation instructions if needed

2. **Test installation**
   ```bash
   # Download latest release
   curl -L https://github.com/YOUR_USERNAME/agentic-framework/archive/refs/tags/v0.2.0.tar.gz | tar xz
   
   # Verify structure
   ls agentic-framework-0.2.0/agentic
   
   # Test init
   cp -r agentic-framework-0.2.0/agentic test-project/
   cd test-project
   # Tell agent to initialize
   ```

3. **Update example project** (if applicable)
   - Update `examples/inited_project/STACK.md` with new version

## Release Cadence

**Suggested schedule:**
- **Patch releases**: As needed (bug fixes)
- **Minor releases**: Every 2-4 weeks (new features)
- **Major releases**: Every 6-12 months (breaking changes)

**Current status:** Pre-1.0 (beta), breaking changes allowed

## Breaking Changes

**If releasing a breaking change (major version bump):**

1. **Document migration path** in CHANGELOG
2. **Create migration guide** in `docs/migrations/`
3. **Update all examples** to new format
4. **Add deprecation warnings** in previous version (if possible)
5. **Consider upgrade tool** (`agentic/tools/upgrade.sh`)

Example migration guide structure:
```markdown
# Migration Guide: v1.x to v2.x

## Breaking Changes
1. Spec format changed from X to Y
2. Tool renamed from A to B

## Migration Steps
1. Backup your project
2. Run upgrade tool: `bash agentic/tools/upgrade.sh`
3. Manually update custom workflows
4. Test thoroughly
```

## Rollback

If a release has critical issues:

```bash
# Delete release on GitHub UI
# Or via CLI:
gh release delete v0.2.0

# Delete tag locally and remotely
git tag -d v0.2.0
git push origin :refs/tags/v0.2.0
```

Then fix issues and re-release with patch version (v0.2.1).

## Notes

- **Never delete a published release** unless it's critically broken
- **Always test release installation** before announcing
- **Keep CHANGELOG.md up to date** (update as you develop)
- **Use conventional commits** to make CHANGELOG generation easier
- **Consider automation** (GitHub Actions) for future releases

