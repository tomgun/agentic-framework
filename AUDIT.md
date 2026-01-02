# Documentation Audit - Outdated References

## Found Issues

### 1. YOUR_USERNAME placeholders
- README.md (1 instance)
- CHANGELOG.md (3 instances)
- UPGRADING.md (7 instances)
- RELEASING.md (3 instances)
- examples/old/example_structure/STACK.md (1 instance)

### 2. Version 0.1.0 references (legacy, in CHANGELOG/examples/old - OK to keep)
- CHANGELOG.md (historical, OK)
- examples/old/* (archived examples, OK)
- UPGRADING.md (examples showing version progression, OK)

### 3. Version 0.2.0 references (should be 0.2.1)
- README.md (1 instance in upgrade section - old temp path)
- UPGRADING.md (multiple instances)
- RELEASING.md (examples using 0.2.0)

### 4. Old folder references (agentic/ instead of .agentic/)
- UPGRADING.md (backup command)
- RELEASING.md (copy command in manual test)
- CHANGELOG.md (old installation example - historical, OK)
- simppeli-mobile/* (different project, ignore)

## Priority Fixes

### High Priority:
1. Replace ALL YOUR_USERNAME → tomgun
2. Update UPGRADING.md to use v0.2.1
3. Update RELEASING.md to use v0.2.1 examples
4. Fix agentic/ → .agentic/ in UPGRADING.md

### Low Priority (OK to leave):
- Historical references in CHANGELOG.md
- examples/old/* (archived)
- Document format versions (format: stack-v0.1.0) - these are format versions, not framework versions

