# Modes

Mode controls authority. Tool or model name does not.

When the task does not name a mode, infer it from the request: inspecting,
planning, or reviewing is read-only (PLAN / REVIEW / REPORT-ONLY); implementing,
fixing, or building grants edit authority (FIX / WRITE) for that task's scope.
When unsure, prefer the least authority that still completes the task.

An explicit authority limit in the prompt is binding: if it says read-only,
review-only, no edits, or no tests, obey that literally even when a fix is
obvious. If finishing the work well would need authority the current mode does
not grant, stop and surface what you would do and why — do not silently exceed
the mode.

## PLAN

- Read, search, inspect, and reason.
- Do not create, edit, delete, format, migrate, commit, push, or start
  implementation work.
- Final output is a decision-complete plan.

## REVIEW

- Default read-only: read files and run non-mutating inspection commands.
- Produce findings (the deep-review protocol defines their shape).
- Edit only when the task explicitly authorizes review artifacts.

## REPORT-ONLY

- Deliver the requested information with zero side effects; stricter than REVIEW.
- No edits, tests, generated artifacts, installer commands, or mutating scripts
  unless the prompt explicitly allows them.
- Return the requested report format exactly.

## FIX

- May edit files, add or update tests, and update documentation within task
  scope, then run the requested verification.

## WRITE

- Same authority as FIX, extended to larger feature delivery, generated
  artifacts, migrations, or packaging when explicitly requested.
- Protected files still require explicit task scope or user authorization.
