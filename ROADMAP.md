# Polaris Roadmap

Durable, plaintext roadmap — diffable, grep-able, GitHub-native. Delete at maturity.

## Now (owner actions)

- **Run `make install-global`** to carry the rules into every repo on this machine.

## Open

- **Verify opencode** auto-load on the installed version — it was not installed
  locally (pi / Codex / Claude Code are confirmed; see `docs/tool-ingestion.md`).
- **Consumers registry.** Add real external consumers to `consumers.md` as they adopt.

Design decisions and rejected review findings (kept so they aren't re-litigated)
live in [`reviews/AUDIT_NOTES.md`](reviews/AUDIT_NOTES.md).

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
