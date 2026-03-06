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
   git add VERSION CHANGELOG.md .agentic/lib/init/STACK.template.md
   git commit -m "chore: bump version to 0.2.0"
   git push origin main
   ```

## Create Release

### Option 1: GitHub UI (Recommended)

1. **Go to GitHub repository**
   - Navigate to: https://github.com/tomgun/agentic-framework

2. **Create new release**
   - Click "Releases" → "Draft a new release"
   - **Tag**: `vX.Y.Z` (must match VERSION file with `v` prefix)
   - **Target**: `main` branch
   - **Title**: `vX.Y.Z`
   - **Description**: Copy from CHANGELOG.md for this version
   - Check "Set as the latest release"
   - Click "Publish release"

3. **GitHub automatically creates:**
   - `agentic-framework-X.Y.Z.tar.gz` (source archive)
   - `agentic-framework-X.Y.Z.zip` (source archive)

### Option 2: GitHub CLI

```bash
# Create and push tag
git tag vX.Y.Z
git push origin vX.Y.Z

# Create release with gh CLI
gh release create vX.Y.Z \
  --title "vX.Y.Z" \
  --notes-file RELEASE_NOTES.md \
  --latest
```

### Option 3: Git Tags Only

```bash
# Create annotated tag
git tag -a vX.Y.Z -m "Release vX.Y.Z"

# Push tag to GitHub
git push origin vX.Y.Z

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
   curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/vX.Y.Z.tar.gz | tar xz
   
   # Verify structure
   ls agentic-framework-X.Y.Z/agentic
   
   # Test init
   cp -r agentic-framework-X.Y.Z/agentic test-project/
   cd test-project
   # Tell agent to initialize
   ```

3. **Update example projects** (if applicable)
   - Update `examples/inited_project/STACK.md` with new version
   - Update `examples/nextjs_evolved/STACK.md` with new version

4. **Announce upgrade path**
   - Ensure `UPGRADING.md` is up to date
   - Test `.agentic/lib/tools/upgrade.sh` works correctly
   - Document any breaking changes in CHANGELOG

## Release Cadence

**Suggested schedule:**
- **Patch releases**: As needed (bug fixes)
- **Minor releases**: Every 2-4 weeks (new features)
- **Major releases**: Every 6-12 months (breaking changes)

**Current status:** Pre-1.0 (beta), breaking changes allowed

## Breaking Changes

**If releasing a breaking change (major version bump):**

1. **Document migration path** in CHANGELOG
2. **Create migration guide** in `docs/migrations/` (e.g., `docs/migrations/v1-to-v2.md`)
3. **Update UPGRADING.md** with version-specific notes
4. **Update all examples** to new format
5. **Test upgrade tool** with breaking changes (`.agentic/lib/tools/upgrade.sh`)
6. **Add deprecation warnings** in previous version (if possible)
7. **Create upgrade automation** if needed (e.g., `.agentic/lib/tools/migrate_v1_to_v2.sh`)

Example migration guide structure:
```markdown
# Migration Guide: v1.x to v2.x

## Breaking Changes
1. Spec format changed from X to Y
2. Tool renamed from A to B

## Migration Steps
1. Backup your project
2. Run upgrade tool: `bash .agentic/lib/tools/upgrade.sh`
3. Manually update custom workflows
4. Test thoroughly
```

## Rollback

If a release has critical issues:

```bash
# Delete release on GitHub UI
# Or via CLI:
gh release delete vX.Y.Z

# Delete tag locally and remotely
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
```

Then fix issues and re-release with patch version (vX.Y.Z).

## Notes

- **Never delete a published release** unless it's critically broken
- **Always test release installation** before announcing
- **Keep CHANGELOG.md up to date** (update as you develop)
- **Use conventional commits** to make CHANGELOG generation easier
- **Consider automation** (GitHub Actions) for future releases

