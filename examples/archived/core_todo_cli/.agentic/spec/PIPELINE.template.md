<!-- format: pipeline-v0.1.0 -->
# Pipeline: F-#### ([Feature Name])

## Configuration
- Pipeline mode: [auto | manual] (from STACK.md)
- Agents: [standard | minimal | full] (from STACK.md)
- Handoff approval: [yes | no] (from STACK.md)
- Started: YYYY-MM-DD HH:MM

## Status
- Current agent: [Agent Name]
- Phase: [in_progress | ready_for_next | blocked | complete]
- Last updated: YYYY-MM-DD HH:MM

## Completed Agents
<!-- Agents add themselves here when done -->
<!-- Example: -->
<!-- - ✅ Research Agent (2026-01-02 11:00) - 60 min -->
<!-- - ✅ Planning Agent (2026-01-02 12:30) - 90 min -->

## Pending Agents
<!-- Agents remaining in pipeline -->
- ⏳ [Next Agent Name]
- ⏳ [Future Agent Name]
- ...

## Handoff Notes
<!-- Each agent adds handoff note for next agent -->
<!-- Format: -->
<!-- ### [From Agent] → [To Agent] -->
<!-- **[From] complete**: [Summary] -->
<!--  -->
<!-- **Context for [To] Agent**: -->
<!-- - Read: [specific files] -->
<!-- - Focus on: [tasks] -->
<!--  -->
<!-- **Next steps**: -->
<!-- 1. [Action 1] -->
<!-- 2. [Action 2] -->
<!--  -->
<!-- **Token budget**: ~[XX]K tokens ([what to load]) -->

## Blockers
<!-- Any issues preventing progress -->
<!-- Example: -->
<!-- - Issue: [Description] -->
<!-- - Escalation: [How to resolve] -->
<!-- - Options: [Possible solutions] -->

## History
<!-- Optional: Detailed log of agent sessions -->
<!-- Example: -->
<!-- ### 2026-01-02 10:30 - Research Agent -->
<!-- - Investigated authentication options -->
<!-- - Created docs/research/auth-strategies-2026-01-02.md -->
<!-- - Recommendation: Auth.js -->

