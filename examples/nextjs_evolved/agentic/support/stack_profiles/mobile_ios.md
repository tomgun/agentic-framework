# Native iOS profile

## Typical choices to decide early
- Language (Swift) and minimum iOS version
- UI framework (SwiftUI/UIKit)
- Persistence (CoreData/SQLite/etc)

## Testing recommendations
- Unit: view models, reducers, pure logic
- Integration: persistence/network boundaries
- UI tests: a small set of critical flows
- Device/simulator strategy:
  - what must run on device
  - what can run on simulator

## `STACK.md` specifics
- Xcode version / build system details
- How to run tests locally and in CI
- How to manage signing (if relevant) without leaking secrets


