---
name: handling-contract-input
description: >
  Process pending user_input from YAML contracts. Use when "pending user input",
  "contract input", "process user input", or dashboard shows pending user_input.
---

# Handling Contract Input

Process pending `user_input` fields from YAML contracts. The `user_input` field is a
communication channel where users write change requests on shipped contracts.

## Workflow

1. **Discover** — `ag contract pending` to list contracts with pending input
2. **Read** — Review the contract's `user_input` field to understand the request
3. **Test first** — Write failing tests that capture the requested change
4. **Implement** — Make the code changes
5. **Add migration** — `ag contract add-migration F-XXXX --trigger user_request --reason "description"`
6. **Clear input** — `ag contract set F-XXXX user_input ""` to mark as processed
7. **Verify** — `ag contract check F-XXXX` to ensure contract health

## Key Points

- `user_input` is exempt from migration requirements (it's a communication channel, not spec content)
- Process one contract at a time — complete the full cycle before moving to the next
- The migration entry documents the change; clearing `user_input` confirms processing
- If the request is unclear, use `blocker.sh` to escalate to the user
