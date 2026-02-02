"""
Tests for F-0002: List Notes

Uses explicit feature naming convention: test_F0002_*.py
"""
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])

from src.notes import NotesManager


class TestListNotes:
    """Tests for listing notes."""

    def test_list_empty_returns_empty_list(self):
        """Listing notes when none exist returns empty list."""
        manager = NotesManager()
        notes = manager.list_notes()

        assert notes == []

    def test_list_returns_all_notes(self):
        """Listing notes returns all created notes."""
        manager = NotesManager()
        manager.create_note("Note 1", "Content 1")
        manager.create_note("Note 2", "Content 2")

        notes = manager.list_notes()

        assert len(notes) == 2

    def test_get_note_returns_correct_note(self):
        """Getting a note by ID returns the correct note."""
        manager = NotesManager()
        created = manager.create_note("Target", "Find me")

        found = manager.get_note(created.id)

        assert found is not None
        assert found.title == "Target"

    def test_get_nonexistent_note_returns_none(self):
        """Getting a non-existent note returns None."""
        manager = NotesManager()

        found = manager.get_note(999)

        assert found is None
