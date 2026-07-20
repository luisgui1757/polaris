# Workflow

The ordered procedure of making a change. References modes and testing rather
than restating them.

## Before Editing

- Confirm the active mode grants write authority.
- Identify the source of truth for the behavior you are changing.
- Inspect nearby code and documentation before choosing an implementation
  pattern.
- Before non-trivial work, capture the relevant baseline so verification can
  distinguish regressions from pre-existing failures.

## During Editing

- Prefer structured parsers and repository helpers over ad hoc text handling.
- Avoid dense one-line commands for non-trivial logic; use checked-in helpers or
  clear, reviewable scripts instead.
- Preserve user changes and unrelated worktree state; never overwrite, revert,
  reformat, or delete files the task did not ask you to touch.
- Do not hand-edit generated artifacts. Edit the source inputs, run the
  generator, and verify the generated output instead.
- Do not add dependencies, run installers, start services, perform migrations, or
  use networked tooling unless the task requires it and repository practice
  justifies it.

## Documentation

- Update the relevant Markdown in the same change whenever code, behavior, or
  architecture changes — roadmaps, status files, READMEs, and ledgers included.
- When a finding is rejected as a false alarm, record the reason where future
  reviewers will find it.

## Verification

- Run the repository's relevant focused checks after a narrow change; run the
  full gate when the repository requires it for non-trivial work.
- Tie verification evidence to the exact commit and produced artifact that will
  ship; results from another revision or a source tree alone are not proof of
  the delivered state.
- A check you did not run is not evidence. Report which checks ran and which were
  intentionally skipped.

## Git

- Use branches, pull requests, and required checks for non-trivial work when the
  repository defines that workflow; do not bypass hooks, checks, or review gates
  without explicit permission.
- Keep generated artifacts reproducible and fail loudly when they drift.
- Follow the repository's commit attribution and provenance policy; do not invent
  trailers without an explicit project or user requirement.
- Clean up temporary worktrees, branches, caches, and scratch files when done.

## Handoff

- Summarize what changed, why, and what verification proves.
- Call out residual risk plainly.
