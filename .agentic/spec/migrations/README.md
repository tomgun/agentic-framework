# Spec Migrations

This directory contains the evolution history of specs as atomic changes.

**Concept by**: Arto Jalkanen

## Purpose

Track HOW we arrived at current specs, not just WHAT the specs are.

## Benefits

- Smaller context windows for AI (read 3-5 migrations, not entire spec)
- Natural audit trail of decisions
- Can regenerate system from history
- Better for parallel agent work

## Usage

See: `.agentic/workflows/spec_migrations.md`

## Files

- `_index.json` - Auto-generated registry
- `001_*.md` - Individual migrations (atomic changes)
