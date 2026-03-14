# Framework Verification — Build Agent

You are building a project from scratch to verify the agentic framework works end-to-end.

## Your Task

Build the project described in the vision below using ONLY the framework's `ag` commands. Follow the standard workflow:

1. Run `ag kickoff "{vision}"` to generate features and specs
2. If kickoff produces a staging area, run `ag kickoff --approve` to accept
3. Run `ag implement F-XXXX` for each generated feature
4. Follow the framework workflow: plan → spec → implement → test → commit
5. Run `ag auto verify` to validate tests pass
6. Run `ag done F-XXXX` for each completed feature

## Vision

{vision}

## Stack

{stack_description}

## Settings

This project uses profile `{profile}` with `{git_workflow}` git workflow.

## Rules

- Use `ag` commands for ALL workflow actions — do not bypass the framework
- Follow the prompts and instructions each `ag` command prints
- If a command fails, report the full error output — do NOT retry silently
- Do NOT create files outside the project directory
- Do NOT modify `.agentic/lib/` files — those are the framework source
