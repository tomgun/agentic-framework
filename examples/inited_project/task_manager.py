"""
Task Manager - Core business logic

@feature F-0001: Add tasks
@feature F-0002: List tasks  
@feature F-0003: Complete tasks
"""

import json
from pathlib import Path
from typing import TypedDict


class Task(TypedDict):
    """Task data structure"""
    id: int
    title: str
    completed: bool


class TaskManager:
    """
    Manages tasks with file persistence
    
    @feature F-0001: add_task()
    @feature F-0002: list_tasks()
    @feature F-0003: complete_task()
    """
    
    def __init__(self, storage_path: str = "tasks.json"):
        self.storage_path = Path(storage_path)
        self.tasks: list[Task] = []
        self.next_id: int = 1
        self.load()
    
    def add_task(self, title: str) -> int:
        """
        Add a new task
        
        @feature F-0001
        @acceptance spec/acceptance/F-0001.md
        
        Returns: task ID
        """
        task: Task = {
            "id": self.next_id,
            "title": title,
            "completed": False
        }
        self.tasks.append(task)
        task_id = self.next_id
        self.next_id += 1
        self.save()
        return task_id
    
    def list_tasks(self) -> list[Task]:
        """
        List all tasks
        
        @feature F-0002
        @acceptance spec/acceptance/F-0002.md
        
        Returns: list of tasks
        """
        return self.tasks.copy()
    
    def complete_task(self, task_id: int) -> bool:
        """
        Mark a task as complete
        
        @feature F-0003
        @acceptance spec/acceptance/F-0003.md
        
        Returns: True if task found and completed, False otherwise
        """
        for task in self.tasks:
            if task["id"] == task_id:
                task["completed"] = True
                self.save()
                return True
        return False
    
    def save(self) -> None:
        """Save tasks to JSON file"""
        data = {
            "tasks": self.tasks,
            "next_id": self.next_id
        }
        self.storage_path.write_text(json.dumps(data, indent=2))
    
    def load(self) -> None:
        """Load tasks from JSON file"""
        if self.storage_path.exists():
            data = json.loads(self.storage_path.read_text())
            self.tasks = data.get("tasks", [])
            self.next_id = data.get("next_id", 1)

