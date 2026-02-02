"""Simple todo CLI implementation.

@feature CLI entry point with argparse command dispatch
"""
import sys
from .commands.add import add_task


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print("Usage: todo add <description>")
        return
    
    command = sys.argv[1]
    
    if command == "add":
        if len(sys.argv) < 3:
            print("Usage: todo add <description>")
            return
        description = " ".join(sys.argv[2:])
        task = add_task(description)
        print(f"✓ Added task #{task.id}: {task.description}")
    else:
        print(f"Unknown command: {command}")


if __name__ == "__main__":
    main()

