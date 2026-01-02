# Non-Functional Requirements

## NFR-0001: Performance
- **Requirement**: Fast response for small task lists
- **Metric**: <100ms for operations on <1000 tasks
- **Affected features**: F-0001, F-0002, F-0003
- **Verification**: Manual testing (simple JSON file is fast enough)
- **Status**: met

## NFR-0002: Data persistence
- **Requirement**: Tasks must not be lost
- **Metric**: 100% persistence reliability for successful operations
- **Affected features**: F-0001, F-0003
- **Verification**: `test_task_persistence`
- **Status**: met

## NFR-0003: Code quality
- **Requirement**: Clean, typed, tested code
- **Metric**: 
  - Type hints on all functions
  - >90% test coverage
  - All tests passing
- **Affected features**: All
- **Verification**: pytest, type checking
- **Status**: met
