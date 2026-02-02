# Technical Specification

## Architecture overview
- Style: Simple CLI application
- Key constraints from `STACK.md`: Python 3.12, single-user, local file storage

## Components

### TaskManager (task_manager.py)
**Responsibilities:**
- Add new tasks
- List all tasks
- Mark tasks as complete
- Persist to JSON file

**Public interface:**
```python
class TaskManager:
    def add_task(title: str) -> int
    def list_tasks() -> list[Task]
    def complete_task(task_id: int) -> bool
    def save() -> None
    def load() -> None
```

### CLI (task_cli.py)
**Responsibilities:**
- Parse command-line arguments
- Call TaskManager methods
- Display results to user

**Commands:**
```bash
task_cli.py add <title>
task_cli.py list
task_cli.py complete <id>
```

## Data model

### Task
```python
{
  "id": int,
  "title": str,
  "completed": bool
}
```

### Storage format (tasks.json)
```json
{
  "tasks": [
    {"id": 1, "title": "Buy milk", "completed": false},
    {"id": 2, "title": "Write code", "completed": true}
  ],
  "next_id": 3
}
```

## Technology stack
- Python 3.12 (type hints)
- pytest (testing)
- JSON (persistence)
- argparse (CLI)

## Testing strategy
- TDD: Write tests first
- Unit tests for TaskManager
- Integration test for CLI (optional)
- Target: 100% coverage of business logic

## Non-functional requirements
- See spec/NFR.md

## Deployment
- Local script only
- No installation required (just run `python task_cli.py`)
