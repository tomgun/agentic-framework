# JUCE VST/AU plugin profile

## Constraints to make explicit
- Target plugin formats (VST3/AU/AAX) and host(s) you will test on
- Realtime safety rules (no allocations/locks in audio thread, etc.)
- Supported sample rates/block sizes

## Testing recommendations
- Unit: pure DSP utilities, parameter mapping, state serialization
- Audio I/O golden tests (offline):
  - feed deterministic input buffers
  - compare output to golden references (with tolerance)
- Host automation tests (offline if possible):
  - parameter changes over time
  - state save/restore
- Performance/realtime budget checks:
  - max CPU per block (define budget)
  - memory allocations during `processBlock` must be zero

## Repo notes
- If you rely on a host/CLI test runner, describe it in `STACK.md` and add commands under “Testing”.
- Consider a small “test host” executable (or existing tool) to run automated buffer tests.


