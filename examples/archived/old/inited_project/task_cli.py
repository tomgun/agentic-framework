"""
Task CLI - Command-line interface

@feature F-0001: add command
@feature F-0002: list command
@feature F-0003: complete command
"""

import argparse
import sys
from task_manager import TaskManager


def main():
    """
    CLI entry point
    
    @feature F-0001, F-0002, F-0003
    """
    parser = argparse.ArgumentParser(description="Simple task manager")
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # Add command
    add_parser = subparsers.add_parser("add", help="Add a new task")
    add_parser.add_argument("title", help="Task title")
    
    # List command
    subparsers.add_parser("list", help="List all tasks")
    
    # Complete command
    complete_parser = subparsers.add_parser("complete", help="Mark task as complete")
    complete_parser.add_argument("task_id", type=int, help="Task ID to complete")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    manager = TaskManager()
    
    if args.command == "add":
        # @feature F-0001
        task_id = manager.add_task(args.title)
        print(f"Added task #{task_id}: {args.title}")
    
    elif args.command == "list":
        # @feature F-0002
        tasks = manager.list_tasks()
        if not tasks:
            print("No tasks found.")
        else:
            for task in tasks:
                status = "✓" if task["completed"] else " "
                print(f"[{status}] #{task['id']}: {task['title']}")
    
    elif args.command == "complete":
        # @feature F-0003
        if manager.complete_task(args.task_id):
            print(f"Completed task #{args.task_id}")
        else:
            print(f"Task #{args.task_id} not found")
            sys.exit(1)


if __name__ == "__main__":
    main()

