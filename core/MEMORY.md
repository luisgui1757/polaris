# Memory

- Write durable memory only when authorized by the user or an active memory
  policy — not by default.
- Store stable decisions, invariants, and repeated failure modes, each with
  enough source and date context to later judge whether it has drifted.
- Do not store private data, secrets, raw transcripts, or local-only paths in a
  reusable rules repository.
- Keep updates append-only unless the user explicitly approves a correction.
- A recalled memory reflects what was true when written; before acting on one
  that names a file, flag, or value, confirm it still holds.
