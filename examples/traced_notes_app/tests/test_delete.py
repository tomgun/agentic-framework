"""
Tests for delete functionality.

This file does NOT use explicit feature naming (test_F####_*.py).
Instead, it will be mapped via import tracing:
- This file imports from src/notes.py
- src/notes.py has @feature F-0003 on delete_note
- Therefore this test is mapped to F-0003 with medium confidence
"""
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])

from src.notes import NotesManager


class TestDeleteNotes:
    """Tests for deleting notes."""

    def test_delete_existing_note_returns_true(self):
        """Deleting an existing note returns True."""
        manager = NotesManager()
        note = manager.create_note("To Delete", "Content")

        result = manager.delete_note(note.id)

        assert result is True

    def test_delete_removes_note_from_list(self):
        """Deleting a note removes it from the list."""
        manager = NotesManager()
        note = manager.create_note("To Delete", "Content")
        manager.delete_note(note.id)

        notes = manager.list_notes()

        assert len(notes) == 0

    def test_delete_nonexistent_returns_false(self):
        """Deleting a non-existent note returns False."""
        manager = NotesManager()

        result = manager.delete_note(999)

        assert result is False
