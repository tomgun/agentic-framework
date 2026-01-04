# Cursor Workflow Prompts for Agentic AI Framework

This directory contains ready-to-use prompts for common workflows in Cursor when using the Agentic AI Framework.

## How to Use

1. Copy the prompt text from the relevant file
2. Paste it into your Cursor chat
3. Cursor will follow the framework's guidelines automatically

## Available Prompts

### Session Management
- **`session_start.md`** - Start a new coding session with proper context loading
- **`session_end.md`** - End a session with proper documentation updates

### Feature Development (Core+PM Mode)
- **`feature_start.md`** - Begin implementing a new feature
- **`feature_test.md`** - Create tests for a feature (TDD workflow)
- **`feature_complete.md`** - Mark a feature as complete with all updates

### Spec Management (Core+PM Mode)
- **`migration_create.md`** - Create a new spec migration
- **`spec_update.md`** - Update specs after implementation

### Core Mode
- **`product_update.md`** - Update PRODUCT.md after changes
- **`quick_feature.md`** - Implement a simple feature in Core mode

### Quality & Maintenance
- **`run_quality.md`** - Run quality checks before commit
- **`fix_issues.md`** - Fix linter/test failures
- **`retrospective.md`** - Trigger a project retrospective

### Research & Planning
- **`research.md`** - Deep dive into a technology or approach
- **`plan_feature.md`** - Plan a complex feature before implementation

## Tips

- Always specify the feature ID (e.g., F-0010) when working on features in Core+PM mode
- Use the session_start prompt at the beginning of each work session
- Use the session_end prompt before taking a break
- Run quality checks before committing

## Framework Documentation

For full documentation, see:
- `.agentic/START_HERE.md`
- `.agentic/DEVELOPER_GUIDE.md`
- `.agentic/README.md`

