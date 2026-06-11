# Testing

The single source for test rules.

- Test behavior, not implementation details. One behavior per test, arranged as
  arrange / act / assert.
- Add a focused regression test for every fix, and a legacy-shape test for every
  persisted-data change.
- Mock only at system boundaries (network, filesystem, time, process); never mock
  internal functions to force a desired result.
- Prefer deterministic, minimal fixtures.
- For numerical behavior, test shape, monotonic relationships, boundary cases,
  and tolerance-appropriate values.
- For persistence, test old shapes and missing new fields.
- For generated artifacts, test both the source metadata and the rendered output.
- If a bug pattern appears in one place, search for other instances before
  closing it.
