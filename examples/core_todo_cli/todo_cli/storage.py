"""JSON storage for tasks.

@feature Atomic JSON file storage with corruption protection
"""
import json
import os
import tempfile
from pathlib import Path
from typing import List

from .models import Task


def get_storage_path() -> Path:
    """Get path to tasks JSON file (XDG_DATA_HOME compliant)."""
    if os.name == 'nt':  # Windows
        base = Path(os.getenv('APPDATA', '~/.local/share')).expanduser()
    else:  # Linux/macOS
        base = Path(os.getenv('XDG_DATA_HOME', '~/.local/share')).expanduser()
    
    storage_dir = base / 'todo-cli'
    storage_dir.mkdir(parents=True, exist_ok=True)
    return storage_dir / 'todos.json'


def load_tasks() -> List[Task]:
    """Load tasks from JSON file."""
    path = get_storage_path()
    
    if not path.exists():
        return []
    
    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return [Task.from_dict(t) for t in data.get('tasks', [])]
    except (json.JSONDecodeError, KeyError):
        # Corrupted file, start fresh
        return []


def save_tasks(tasks: List[Task]) -> None:
    """Save tasks to JSON file (atomic write to prevent corruption)."""
    path = get_storage_path()
    
    data = {
        'version': '1.0',
        'tasks': [t.to_dict() for t in tasks]
    }
    
    # Atomic write: write to temp file, then rename
    with tempfile.NamedTemporaryFile(
        mode='w',
        encoding='utf-8',
        dir=path.parent,
        delete=False,
        suffix='.tmp'
    ) as tf:
        json.dump(data, tf, indent=2)
        temp_path = tf.name
    
    # Atomic replace
    os.replace(temp_path, path)

