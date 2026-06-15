# Polaris Roadmap

Durable, plaintext roadmap — diffable, grep-able, GitHub-native. Delete at maturity.

## Now (owner actions)

- **Tag `v0.1.0`** when ready (`docs/RELEASE.md`) — optional, not a blocker.
- **Run `make install-global`** to carry the rules into every repo on this machine.

## Open

- **Verify opencode** auto-load on the installed version — it was not installed
  locally (pi / Codex / Claude Code are confirmed; see `docs/tool-ingestion.md`).
- **Consumers registry.** Add real external consumers to `consumers.md` as they adopt.

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
- **Public-launch audit "history leak" (P1) — FALSE ALARM, do not re-open.** A
  2026-06-12 adversarial audit flagged a private denylist in commit `36fa204`,
  but that commit is **not** in this public repo: `origin/main` is a clean
  3-commit orphan-root history and the old leaky commit lives only in the
  **private** `__polaris__` repo (plus a local tag, since deleted). Verified:
  `git merge-base --is-ancestor 36fa204 origin/main` → false; HEAD
  `MANIFEST.json` carries only generic home-path patterns. The audit ran
  `git log --all` over the local clone and swept in orphaned pre-cleanup history.
  Every other audit finding was P3 and has been resolved (see `CHANGELOG.md`).

## Shipped

Auto-ingestion installer (`--target` / `--global` / `--check` / `--remove`);
brand-neutral, single-axis core (MODES → INVARIANTS → EXECUTION → WORKFLOW →
TESTING → MEMORY); two-tier privacy with redaction + path/manifest scans, plus
**gitleaks** secret-shape scanning; `tools/status` / `verify-vendor` /
`release-check`; bats suite + Linux/macOS CI matrix with **gitleaks, yamllint,
and editorconfig-checker** gated by `ci` (ShellCheck **blocking**) plus
**check-jsonschema** enforcing the canonical manifest schema; branch-protection
rulesets (owner-only `always` bypass for direct-push + CI/review override);
threat-model / tool-ingestion / contributing / security / release docs; jq
parser; enforced budget; determinism. **Public launch:** free Actions with `ci`
green on Linux + macOS, fork-PR approval = all external contributors, private
vulnerability reporting enabled. **Windows install path** (`tools/install.ps1`,
byte-identical to bash, gated by a `windows-latest` CI job). **Gold-standard
hardening:** strict no-silent-skip gates (`POLARIS_STRICT`), rule clauses that
name the roads to a fake-green (no test-tampering / error-swallowing / checker-
silencing / stub-shipping; blast-radius-bound "calibrate to stakes"). Full
detail in `CHANGELOG.md`.
