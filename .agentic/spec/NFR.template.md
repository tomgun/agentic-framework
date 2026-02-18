# NFR (Non-Functional Requirements) (Template)

<!-- format: nfr-v0.1.0 -->

Purpose: capture cross-cutting constraints that apply across many features (performance, security, realtime safety, reliability, etc.) in a stable, referenceable way.

## Vocabulary
- NFRs are constraints/qualities, not features.
- Each NFR gets a stable ID: `NFR-####`, …
- Features can link to NFR IDs in `spec/FEATURES.md` **when relevant**, but most features will omit NFR links.
- Prefer one of these patterns:
  - **Global NFR**: set “Applies to: all (unless stated otherwise)”
  - **Scoped NFR**: list the components/features it applies to

---

## NFR-####: Example performance budget
- Category: performance
- Statement: p95 request latency < 200ms for critical endpoints
- Applies to: <!-- components/features -->
- How to measure: <!-- benchmark/test/tool -->
- Where enforced:
  - Tests: <!-- perf tests -->
  - CI: <!-- checks -->
- Current status: unknown  <!-- unknown | partial | met | violated -->
- Acceptance: spec/acceptance/NFR-####.md
- Notes:


