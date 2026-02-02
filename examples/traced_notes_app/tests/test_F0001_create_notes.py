"""
Tests for F-0001: Create Notes

Uses explicit feature naming convention: test_F0001_*.py
This allows automatic test→feature mapping via coverage.py --test-mapping
"""
import sys
sys.path.insert(0, str(__file__).rsplit('/', 2)[0])

from src.notes import NotesManager


class TestCreateNotes:
    """Tests for the create_note functionality."""

    def test_create_note_returns_note_with_id(self):
        """Creating a note should return a Note with an ID."""
        manager = NotesManager()
        note = manager.create_note("Test Title", "Test content")

        assert note.id == 1
        assert note.title == "Test Title"
        assert note.content == "Test content"

    def test_create_multiple_notes_have_unique_ids(self):
        """Each created note should have a unique ID."""
        manager = NotesManager()
        note1 = manager.create_note("First", "Content 1")
        note2 = manager.create_note("Second", "Content 2")

        assert note1.id != note2.id
        assert note1.id == 1
        assert note2.id == 2

    def test_create_note_with_empty_content(self):
        """Notes can be created with empty content."""
        manager = NotesManager()
        note = manager.create_note("Title Only", "")

        assert note.title == "Title Only"
        assert note.content == ""
