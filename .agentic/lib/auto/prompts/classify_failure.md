# Failure Classification

Classify the following error output from a framework verification run.

## Error Output

```
{error_output}
```

## Classification

Respond with EXACTLY ONE of these classifications:

- **framework_bug** — The error is caused by a bug in `.agentic/lib/` framework code (Python traceback, bash script error, missing file in framework)
- **agent_error** — The error is caused by the AI agent making a bad choice (wrong command, incorrect file path, logic error in generated code)
- **external** — The error is caused by external factors (network, rate limits, missing dependencies, permissions)

Respond with just the classification word, nothing else.
