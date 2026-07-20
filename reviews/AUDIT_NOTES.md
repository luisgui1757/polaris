# Sentinel — design decisions & rejected findings

A durable record of choices made deliberately and review findings rejected as
false alarms, so they are not re-litigated. This is forensic detail that does not
belong in the newcomer-facing `ROADMAP.md`.

## Resolved by design

- **Copilot global automation** — deliberately not automated: Copilot has no
  stable global file; the manual VS Code / github.com path is documented in
  `docs/tool-ingestion.md`.
- **Denylist case-insensitivity / inflection** — kept case-sensitive and
  whole-word by design (protects precision so a 3-letter term can't trip a longer
  word); enumerate casings explicitly in the denylist when needed.
- **No-jq manifest fallback** — kept as documented best-effort; jq is preferred
  and CI installs it.
- **Owner direct-push to main — SUPERSEDED 2026-07-20.** The former design made
  the owner the sole `always` bypass actor so work could move directly to
  `main`. The gold-standard governance review rejected that tradeoff: unfinished
  work stays on a local or private branch, while public `main` keeps
  unbypassable integrity evidence. See the reconsideration below.

## Reconsidered decisions — 2026-07-20

- **Integrity has no bypass.** Required `ci`, CodeQL, deletion protection, and
  non-fast-forward protection apply to every actor, including the owner.
- **Owner discretion is PR-scoped.** The owner remains the sole bypass actor on
  review and update rules, but only in `pull_request` mode. This preserves the
  single-maintainer path without permitting an untested direct push.
- **One branch-policy source.** Classic branch protection was removed from the
  declared posture because overlapping enforcement creates stale contexts and
  ambiguous effective policy. The three rulesets are the source of truth.
- **WIP privacy is not a main-integrity exception.** Sensitive or incomplete
  work belongs on a local/private branch until it is publication-ready; avoiding
  a public PR diff does not justify bypassing the exact artifact that ships.

## Rejected findings (do not re-open)

- **Public-launch audit "history leak" (P1) — FALSE ALARM.** A 2026-06-12
  adversarial audit flagged a private denylist in an early commit, but that commit
  is **not** in this public repo: `origin/main` is a clean orphan-root history and
  the old leaky commit lives only in a now-private predecessor repo (plus a local
  tag, since deleted). Verified at the time: the flagged commit is not an ancestor
  of `origin/main`, and HEAD `MANIFEST.json` carries only generic home-path
  patterns. The audit had run `git log --all` over a local clone and swept in
  orphaned pre-cleanup history. Every other audit finding was P3 and resolved
  (see `CHANGELOG.md`).
- **A short denylist term "matched" in git history** — FALSE ALARM: a 3-letter
  term appeared only as a substring of a longer, unrelated common word; the
  production scanner is whole-word, so `tools/check` does not flag it.
