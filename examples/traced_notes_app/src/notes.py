"""
Notes management module.
Demonstrates @feature annotations for spec-code traceability.
"""
from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional


@dataclass
class Note:
    """A simple note with title and content."""
    id: int
    title: str
    content: str
    created_at: datetime = field(default_factory=datetime.now)


class NotesManager:
    """Manages a collection of notes."""

    def __init__(self):
        self._notes: dict[int, Note] = {}
        self._next_id = 1

    # @feature F-0001
    def create_note(self, title: str, content: str) -> Note:
        """Create a new note with the given title and content."""
        note = Note(
            id=self._next_id,
            title=title,
            content=content,
        )
        self._notes[note.id] = note
        self._next_id += 1
        return note

    # @feature F-0002
    def list_notes(self) -> list[Note]:
        """Return all notes, sorted by creation time (newest first)."""
        return sorted(
            self._notes.values(),
            key=lambda n: n.created_at,
            reverse=True,
        )

    # @feature F-0002
    def get_note(self, note_id: int) -> Optional[Note]:
        """Get a specific note by ID."""
        return self._notes.get(note_id)

    # @feature F-0003
    def delete_note(self, note_id: int) -> bool:
        """Delete a note by ID. Returns True if deleted, False if not found."""
        if note_id in self._notes:
            del self._notes[note_id]
            return True
        return False

    # @feature F-0004 (not implemented - planned feature)
    def search_notes(self, query: str) -> list[Note]:
        """Search notes by title or content. NOT YET IMPLEMENTED."""
        raise NotImplementedError("F-0004: Search feature is planned but not implemented")
