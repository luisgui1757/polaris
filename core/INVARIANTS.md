# Invariants

Durable engineering truths. These hold regardless of task, language, or phase.

## Correctness

- Before changing behavior, state in one sentence what you are changing and why.
- Trace every behavior change to a source of truth: a documented requirement, a
  failing regression test, a published specification, or an explicit user
  instruction.
- When you cannot produce a correct result, stop or raise — never emit a guess
  that downstream code will trust. A crash is recoverable; a silently wrong
  value is not.
- Never silence an error by catching and discarding it (empty catch, bare
  except, ignored rejection); handle it or let it propagate — a swallowed failure
  is the silently-wrong value above, one layer up.
- Satisfy a checker, never silence it: an inline suppression of a type, lint, or
  compiler diagnostic is a behavior change needing the same source-of-truth
  justification as any other, surfaced not buried, and legitimate only for a
  documented false positive.
- Handle empty, single-element, and boundary inputs, serialization boundaries,
  and numerical hazards before calling work complete.
- Before reporting a conclusion, check at least one plausible alternative
  explanation; state any uncertainty rather than implying false precision.
- Tie confidence to evidence; mark a fact you did not verify this session as
  unverified rather than asserting it.

## Architecture

- Prefer the repository's established patterns over new abstractions.
- Keep stable core logic independent of UI, transport, storage, and tool
  adapters; dependencies flow from outer mechanisms toward stable policy, not
  the reverse.
- Validate and bound external input at the system boundary; reject it there
  rather than deep inside.
- Do not silently change persisted data shape, external contracts, or workflow
  semantics.
- Treat secrets and private data as toxic: never commit, log, print, or echo
  them. Avoid hardcoded user-specific paths, names, or data patterns; model them
  as configuration.
- Treat executable third-party inputs as supply-chain boundaries: pin immutable
  identities and verify downloaded bytes before execution.
- For multi-step durable or external mutations, validate preconditions and
  concurrent state immediately before writing, then commit atomically or retain
  a tested recovery path and verify the resulting state by readback.
- Add an abstraction only when it removes real, present duplication or matches
  an established local pattern.
- Weight caution by blast radius and reversibility: a local, easily reverted
  change needs less ceremony than a deletion, a migration, a persisted-shape
  change, or an outward-facing action.
