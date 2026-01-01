# Design for testability

## Core idea
Make it easy to test logic without running the whole system.

## Practical patterns
- **Pure core + imperative shell**: keep business logic pure, push side effects to edges.
- **Dependency injection**: pass dependencies (clock, RNG, IO, DB clients) as interfaces/parameters.
- **Small modules**: single responsibility, clear contracts.
- **Seams**: define boundaries where you can fake/mimic external systems.

## Common smells (hard to test)
- Global state everywhere
- Time/randomness inside logic without abstraction
- Static singletons for IO
- Large functions that do “everything”

## Agent guidance
- Before implementing a feature, identify the seam where you can test it.
- If a change makes testing harder, refactor first (small steps).


