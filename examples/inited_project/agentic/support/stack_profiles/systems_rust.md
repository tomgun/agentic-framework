# Stack profile: Rust systems programming

Quick guidance for initializing a Rust systems project with this framework.

## Tech choices

### Language & runtime
- Rust 1.70+ recommended (stable channel)
- Package management: `cargo`
- Edition: 2021

### Testing
- Test framework: built-in `#[test]` and `#[cfg(test)]`
- Property testing: `proptest` or `quickcheck`
- Benchmarking: `criterion`
- Mocking: `mockall` for trait mocking
- Test command: `cargo test`
- Coverage: `cargo-tarpaulin` or `cargo-llvm-cov`

### Common dependencies
- Serialization: `serde` + `serde_json`
- Async: `tokio` or `async-std`
- HTTP: `axum`, `actix-web`, or `warp`
- CLI: `clap`
- Logging: `tracing` + `tracing-subscriber`
- Error handling: `thiserror` or `anyhow`

### Project structure (typical)
```
/src
  main.rs or lib.rs
  /module_a
  /module_b
/tests           # Integration tests
/benches         # Benchmarks
/examples        # Example programs
```

## STACK.md template sections

```markdown
## Build & run
- Build: `cargo build --release`
- Run: `cargo run`
- Test: `cargo test`
- Lint: `cargo clippy`
- Format: `cargo fmt`

## Dependencies
- Add: `cargo add <crate>`
- Update: `cargo update`

## Key constraints
- Rust 1.70+ required
- Compile target: x86_64-unknown-linux-gnu (or specify)
- No unsafe code (or document why if needed)
```

## Test strategy guidance

### Unit tests
- Co-located in same file with `#[cfg(test)]`
- Test module: `mod tests { ... }`

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
    }

    #[test]
    #[should_panic(expected = "overflow")]
    fn test_add_overflow() {
        add(u32::MAX, 1);
    }
}
```

### Integration tests
- Separate `tests/` directory
- Each file is separate test crate
- Test library public API

```rust
// tests/integration_test.rs
use my_crate::public_function;

#[test]
fn test_public_api() {
    assert_eq!(public_function(), expected);
}
```

### Property-based tests
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_reversible(s in ".*") {
        let encoded = encode(&s);
        let decoded = decode(&encoded)?;
        prop_assert_eq!(s, decoded);
    }
}
```

## NFR considerations

For `spec/NFR.md`:
- **Performance**: Zero-cost abstractions, profile hot paths
- **Memory**: Document heap allocations, consider `no_std` if embedded
- **Safety**: No unsafe code (or justify each unsafe block)
- **Concurrency**: Use Rust's ownership to prevent data races
- **Binary size**: May matter for embedded/WASM

Rust-specific NFRs:
- `NFR-0001`: No panics in production code (use `Result` and proper error handling)
- `NFR-0002`: All public APIs documented with `///` comments
- `NFR-0003`: Pass `cargo clippy` with no warnings

## Feature annotations

```rust
// @feature F-0012
// @nfr NFR-0005 (no allocations in this path)
pub fn process_audio_buffer(buffer: &mut [f32]) {
    // implementation
}
```

## Common gotcases

- **Lifetimes**: Document lifetime relationships in structs
- **Error propagation**: Decide on `anyhow` vs `thiserror` early
- **Async runtime**: Pick one (tokio or async-std) and stick with it
- **Feature flags**: Use cargo features to control optional dependencies
- **Compile times**: Consider `sccache` for caching, split into multiple crates

## Acceptance criteria patterns

Rust-specific criteria:
- "Compiles with no warnings on `cargo clippy`"
- "Passes `cargo fmt --check`"
- "No unsafe code blocks (or document safety invariants)"
- "All public APIs have doc comments"
- "Benchmark shows <10μs latency for operation X"

## References

- Rust book: https://doc.rust-lang.org/book/
- Rust API guidelines: https://rust-lang.github.io/api-guidelines/
- Testing: https://doc.rust-lang.org/book/ch11-00-testing.html
- Performance: https://nnethercote.github.io/perf-book/

