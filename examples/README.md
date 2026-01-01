# Examples

This directory contains example projects demonstrating the Agentic Framework in use.

## Examples

### 1. example_structure/
**What it shows:** Empty project structure created by `scaffold.sh`

This is what you get after running the scaffold script but before filling in any content. Shows:
- All required files (STACK.md, STATUS.md, CONTEXT_PACK.md, etc.)
- Directory structure (spec/, docs/, etc.)
- Empty templates ready to be filled

**When to reference:** To understand what files the framework creates and where they live.

### 2. inited_project/ (Next.js Todo App)
**What it shows:** Fully initialized project using the framework

A working Next.js + TypeScript todo application that demonstrates:
- Complete STACK.md (how to build/test)
- Filled-in specs (PRD, Tech Spec, Features with F-#### IDs)
- Test-driven development (unit tests with vitest)
- Feature tracking (F-0001: Add todos, F-0002: Complete todos)
- Agent-friendly documentation
- Real code with `@feature` annotations

**When to reference:** To see what a real project looks like after framework adoption.

**Tech stack:** Next.js 14, React, TypeScript, Vitest

## Using These Examples

**Don't copy these into your project!**

These are for reference/learning only. To start your own project:

```bash
# Download framework release
curl -L https://github.com/tomgun/agentic-framework/archive/refs/tags/v0.1.0.tar.gz | tar xz
cp -r agentic-framework-0.1.0/agentic ./

# Tell your agent to initialize
# Agent will create appropriate structure for YOUR project
```

## Framework Version

These examples are compatible with:
- **Agentic Framework v0.1.0**

If you're using a different version, some files/features may differ.

