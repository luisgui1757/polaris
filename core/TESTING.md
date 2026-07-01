# Testing

The single source for test rules.

- Test behavior, not implementation details. One behavior per test, arranged as
  arrange / act / assert.
- For bug fixes, reproduce the failure through the highest-fidelity practical
  path first. Prefer the end-user or E2E workflow when available; when a narrower
  reproduction is the right proof, state why.
- Add a focused regression test for every fix, and a legacy-shape test for every
  persisted-data change.
- Mock only at system boundaries (network, filesystem, time, process); never mock
  internal functions to force a desired result.
- Never weaken, skip, comment out, or delete a test to make a suite pass; a red
  test is a finding, not an obstacle. Quarantine a genuinely flaky test only with
  explicit authorization and a tracked follow-up.
- Prefer deterministic, minimal fixtures.
- For numerical behavior, test shape, monotonic relationships, boundary cases,
  and tolerance-appropriate values.
- For persistence, test old shapes and missing new fields.
- For generated artifacts, test both the source metadata and the rendered output.
- If a bug pattern appears in one place, search for other instances before
  closing it.
