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
- **Owner direct-push to main** — the owner is the sole ruleset bypass actor in
  `always` mode, so the owner can push straight to `main` (no PR) and override
  `ci`/review; everyone else needs a PR + code-owner review + green `ci`. Kept in
  public **by design** — it avoids leaking work-in-progress into public PR diffs.

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
