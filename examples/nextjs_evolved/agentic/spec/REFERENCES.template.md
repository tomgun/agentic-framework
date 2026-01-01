# REFERENCES (Template)

Purpose: track external resources (papers, docs, examples, repos) that informed design decisions and implementation.

## How to use
- Add references when research informs a feature, ADR, or technical decision
- Link references to the features/ADRs they influenced
- Extract key insights so future sessions don't need to re-read sources
- Keep it concise - this is a pointer system, not a knowledge base

---

## REF-0001: Example reference title
- Type: paper | docs | example | repo | article
- URL: https://...
- Date accessed: YYYY-MM-DD
- Related to:
  - Feature: F-0001
  - ADR: ADR-0001
- Key insights:
  - <!-- 3-5 bullets: what matters from this source -->
- Relevant quotes/sections:
  - <!-- optional: specific sections that matter -->

---

## REF-0002: Another example
- Type: official docs
- URL: https://developer.example.com/api/...
- Date accessed: 2025-12-30
- Related to:
  - Feature: F-0003
  - NFR: NFR-0002
- Key insights:
  - API rate limit is 100 req/min per token
  - Requires OAuth 2.0 with specific scopes
  - Webhook retry logic: exponential backoff, max 3 attempts

