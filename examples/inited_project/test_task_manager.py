"""
Tests for TaskManager

TDD: These tests were written FIRST, then implementation followed.

@feature F-0001: test_add_task
@feature F-0002: test_list_tasks
@feature F-0003: test_complete_task
"""

import pytest
from pathlib import Path
from task_manager import TaskManager


@pytest.fixture
def temp_storage(tmp_path):
    """Provide temporary storage for tests"""
    return tmp_path / "test_tasks.json"


@pytest.fixture
def manager(temp_storage):
    """Provide a fresh TaskManager for each test"""
    return TaskManager(str(temp_storage))


def test_add_task(manager):
    """
    @feature F-0001
    @acceptance spec/acceptance/F-0001.md
    
    Given: Empty task list
    When: Add a task with title "Buy milk"
    Then: Task is added with ID 1
    """
    task_id = manager.add_task("Buy milk")
    assert task_id == 1
    
    tasks = manager.list_tasks()
    assert len(tasks) == 1
    assert tasks[0]["title"] == "Buy milk"
    assert tasks[0]["completed"] is False


def test_list_tasks(manager):
    """
    @feature F-0002
    @acceptance spec/acceptance/F-0002.md
    
    Given: Multiple tasks added
    When: List tasks
    Then: All tasks are returned
    """
    manager.add_task("Task 1")
    manager.add_task("Task 2")
    manager.add_task("Task 3")
    
    tasks = manager.list_tasks()
    assert len(tasks) == 3
    assert tasks[0]["title"] == "Task 1"
    assert tasks[1]["title"] == "Task 2"
    assert tasks[2]["title"] == "Task 3"


def test_complete_task(manager):
    """
    @feature F-0003
    @acceptance spec/acceptance/F-0003.md
    
    Given: Task exists
    When: Complete task by ID
    Then: Task is marked as completed
    """
    task_id = manager.add_task("Buy milk")
    
    # Complete the task
    result = manager.complete_task(task_id)
    assert result is True
    
    # Verify task is completed
    tasks = manager.list_tasks()
    assert tasks[0]["completed"] is True


def test_complete_nonexistent_task(manager):
    """
    @feature F-0003
    @acceptance spec/acceptance/F-0003.md
    
    Given: Task ID doesn't exist
    When: Try to complete task
    Then: Returns False
    """
    result = manager.complete_task(999)
    assert result is False


def test_task_persistence(manager, temp_storage):
    """
    Test that tasks are saved and loaded correctly
    
    Given: Tasks are added
    When: Create new manager with same storage
    Then: Tasks are loaded from file
    """
    manager.add_task("Persistent task")
    
    # Create new manager with same storage
    new_manager = TaskManager(str(temp_storage))
    tasks = new_manager.list_tasks()
    
    assert len(tasks) == 1
    assert tasks[0]["title"] == "Persistent task"


def test_auto_increment_ids(manager):
    """
    Test that task IDs auto-increment
    
    @feature F-0001
    """
    id1 = manager.add_task("Task 1")
    id2 = manager.add_task("Task 2")
    id3 = manager.add_task("Task 3")
    
    assert id1 == 1
    assert id2 == 2
    assert id3 == 3

