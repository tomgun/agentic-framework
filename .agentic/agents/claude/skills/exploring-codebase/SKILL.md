---
name: exploring-codebase
description: >
  Navigate and understand codebase structure, find files, trace dependencies.
  Use when user says "find", "where is", "explore", "show me", "what files",
  "how does this work", "codebase structure", or asks about code location.
  Do NOT use for: modifying code (use implementing-features), reviewing
  changes (use reviewing-code), web research (use researching-topics).
compatibility: "Requires Claude Code with file access."
allowed-tools: [Read, Glob, Grep, Bash]
metadata:
  author: agentic-framework
  version: "${VERSION}"
---

# Exploring Codebase

Quick codebase navigation, file finding, and structure understanding.

## Instructions

### Step 1: Understand the Question

Determine what the user is looking for:
- A specific file or function?
- How a feature works?
- Project structure overview?
- Dependencies between components?

### Step 2: Search Efficiently

Use the right tool for the task:
- **File by name**: `Glob` with pattern (e.g., `**/*.test.js`)
- **Code by content**: `Grep` with pattern (e.g., `function calculateTotal`)
- **Structure overview**: `ls` key directories
- **Dependency tracing**: Read import/require statements

Start broad, then narrow. Check `CONTEXT_PACK.md` for "Where to look first."

### Step 3: Present Findings

Organize findings clearly:
- File paths with brief descriptions
- Key functions or classes with their purpose
- Dependency relationships if relevant
- Suggest next steps if the user needs to modify something

## Examples

**Example 1: Finding where something is defined**
User says: "Where is the auth middleware?"
Steps taken:
1. Grep for "auth" in middleware directories
2. Found: `src/middleware/auth.js` — JWT verification
3. Also found: `src/middleware/rbac.js` — role-based access
Result: "Auth middleware is at `src/middleware/auth.js`. It handles JWT verification. Role-based access is separate in `rbac.js`."

**Example 2: Understanding project structure**
User says: "How is the project organized?"
Steps taken:
1. List top-level directories
2. Read key config files (package.json, tsconfig, etc.)
3. Check CONTEXT_PACK.md for architecture overview
Result: Structured overview of directories, their purposes, and key files.

## Troubleshooting

**Can't find the file**
Cause: Different naming convention or location than expected.
Solution: Try broader Glob patterns, check imports from known files, or search for related strings.
