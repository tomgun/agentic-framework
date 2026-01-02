"""Command: add a new task."""
from ..models import Task
from ..storage import load_tasks, save_tasks


def add_task(description: str) -> Task:
    """Add a new task.
    
    @feature Add command - creates task with auto-incremented ID
    """
    tasks = load_tasks()
    
    # Auto-increment ID
    next_id = max([t.id for t in tasks], default=0) + 1
    
    new_task = Task(id=next_id, description=description, done=False)
    tasks.append(new_task)
    
    save_tasks(tasks)
    return new_task

