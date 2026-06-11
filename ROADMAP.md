# Polaris Roadmap

Durable, plaintext roadmap — diffable, grep-able, GitHub-native. Delete at maturity.

## Now (owner actions)

- **Publication.** Public repos get free Actions, so `ci` runs. Flip with
  `gh repo edit --visibility public`, then apply the two public-only Actions
  safety settings (fork-PR approval = all external contributors; enable private
  vulnerability reporting). The codeowner bypass is kept **by design** — review
  is mandatory for everyone else, but the owner can self-merge and override `ci`.
  Optionally tag `v0.1.0` (`docs/RELEASE.md`).
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

## Shipped

Auto-ingestion installer (`--target` / `--global` / `--check` / `--remove`);
brand-neutral, single-axis core (MODES → INVARIANTS → EXECUTION → WORKFLOW →
TESTING → MEMORY); two-tier privacy with redaction + path/manifest scans, plus
**gitleaks** secret-shape scanning; `tools/status` / `verify-vendor` /
`release-check`; bats suite + Linux/macOS CI matrix with **gitleaks, yamllint,
and editorconfig-checker** gated by `ci` (ShellCheck advisory); branch-protection
rulesets (with owner CI-override while private); threat-model / tool-ingestion /
contributing / security / release docs; jq parser; enforced budget; determinism.
Full detail in `CHANGELOG.md`.
