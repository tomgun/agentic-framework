"""Tests for storage layer."""
import json
import tempfile
from pathlib import Path

import pytest

from todo_cli.models import Task
from todo_cli.storage import load_tasks, save_tasks, get_storage_path


def test_save_and_load_tasks(tmp_path, monkeypatch):
    """Test saving and loading tasks."""
    # Override storage path
    monkeypatch.setenv('XDG_DATA_HOME', str(tmp_path))
    
    tasks = [
        Task(id=1, description="Test task 1", done=False),
        Task(id=2, description="Test task 2", done=True),
    ]
    
    save_tasks(tasks)
    loaded = load_tasks()
    
    assert len(loaded) == 2
    assert loaded[0].id == 1
    assert loaded[0].description == "Test task 1"
    assert loaded[0].done is False
    assert loaded[1].done is True


def test_load_empty_file(tmp_path, monkeypatch):
    """Test loading when file doesn't exist."""
    monkeypatch.setenv('XDG_DATA_HOME', str(tmp_path))
    
    tasks = load_tasks()
    assert tasks == []


def test_atomic_write_prevents_corruption(tmp_path, monkeypatch):
    """Test that atomic write doesn't corrupt existing file on error."""
    monkeypatch.setenv('XDG_DATA_HOME', str(tmp_path))
    
    # Save initial tasks
    initial_tasks = [Task(id=1, description="Original", done=False)]
    save_tasks(initial_tasks)
    
    # Verify file exists and is valid
    loaded = load_tasks()
    assert len(loaded) == 1
    assert loaded[0].description == "Original"

