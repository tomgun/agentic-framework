"""Task data model."""
from dataclasses import dataclass
from typing import List
import json


@dataclass
class Task:
    """A single task.
    
    @feature Simple task model with id, description, done status
    """
    id: int
    description: str
    done: bool = False
    
    def to_dict(self) -> dict:
        """Convert to JSON-serializable dict."""
        return {
            "id": self.id,
            "description": self.description,
            "done": self.done
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> "Task":
        """Create Task from dict."""
        return cls(
            id=data["id"],
            description=data["description"],
            done=data.get("done", False)
        )

