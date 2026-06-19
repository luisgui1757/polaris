# Agent Entrypoint (template)

This is the portable entrypoint any coding assistant reads first.

## Read Order

1. `<vendor>/MANIFEST.json`
2. `<vendor>/core/MODES.md`
3. `<vendor>/core/REVIEW_PROTOCOL.md`
4. `<vendor>/core/INVARIANTS.md`
5. `<vendor>/core/EXECUTION.md`
6. `<vendor>/core/WORKFLOW.md`
7. `<vendor>/core/TESTING.md`
8. `<vendor>/core/MEMORY.md`
9. `<overlay>/...` (your project overlay)

For deep reviews, also read your project's review prompts and ledgers.
`<vendor>/core/BOOTSTRAP.md` describes the vendor/pointer flow and is only needed
when the core is not inlined.

Most setups skip this manual read order entirely: `tools/install` inlines the
core into the tool's native entrypoint, so it auto-loads at startup.

## Emergency Minimum Rules

- [Project-specific safety reminder.]
- Mode controls write authority: PLAN / REVIEW / REPORT-ONLY are read-only;
  FIX / WRITE may edit, test, and document.
- Trace behavior to a source of truth before changing it.
- Run the project's relevant verification; an unrun check is not evidence.
- Tool-specific files are adapters, not independent policy.
