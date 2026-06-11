# Changelog

All notable changes to Polaris. Format follows [Keep a Changelog]; the project
uses [Semantic Versioning]. Consumers pin a version and a `bundle-sha256`.

## [Unreleased]

### Added
- Auto-ingestion installer (`tools/install`): inlines the core into each tool's
  native entrypoint; `--target`, `--global`, `--check`, `--dry-run`, and
  `--remove` (uninstall, preserving surrounding content).
- Two-tier privacy: gitignored `tools/forbidden-terms.local`; whole-working-tree
  leak scan (incl. untracked files, path names, and the manifest) with redaction.
- `core/EXECUTION.md` (always-on execution discipline).
- Observability and provenance: `tools/status`, `tools/verify-vendor`.
- `tests/` bats regression suite; cross-platform (Linux + macOS) CI matrix with a
  stable `ci` gate; ShellCheck (advisory).
- CI `lint` job (required via the `ci` gate): **gitleaks** secret-shape scan,
  **yamllint**, and **editorconfig-checker**, with configs that pass the tree.
- `consumers.md` records Polaris's own dogfood install.
- House repo config: branch-protection rulesets, `settings.yml`, CODEOWNERS, PR
  template, `.editorconfig`/`.gitattributes`, `scripts/apply-repo-safeguards.sh`.
- Docs: `docs/THREAT_MODEL.md`, `docs/tool-ingestion.md`, `CONTRIBUTING.md`,
  `SECURITY.md`, `docs/RELEASE.md`, `schemas/manifest.schema.json`.
- `jq`-preferred manifest parser (string-aware; decodes escapes), locale
  determinism (`LC_ALL=C`), and an enforced injected-bundle byte budget.

### Changed
- Restructured core into single-axis files: `PRINCIPLES`→`INVARIANTS`,
  `PRACTICES`→`EXECUTION`, `MODES` first; moved testing/git out of the old
  PRINCIPLES and de-duplicated repeated maxims to one home each.
- The injected bundle is now **brand-neutral**: no "Polaris"/repo names or
  source paths in the content; the managed-block marker is `AGENT-RULES`; the
  bundle renders as one document with nested section headings.
- Repo-scope `tools/install --check` now fails on a missing required adapter.
- Sharpened and de-duplicated the core rules (fail-safe correctness, blast-radius
  caution, binding mode authority, memory write-authority, bounded retry loop).

### Fixed
- Empty-bundle guard: a malformed/unreadable manifest fails loudly instead of
  rendering nothing and hashing to the empty-string sha (jq/no-jq agreement).
- Manifest projection uses `jq 'del(.forbidden_core_terms)'` when jq is present;
  budget rejects non-integers; `tools/status` reads the sha only from the
  generated header line.
- CI `ci` gate runs `if: always()` and fails unless every matrix leg succeeded
  (a skipped required check can read as green otherwise).
- `apply-repo-safeguards.sh` fails closed without jq / a resolved owner id.
- P3 polish: CRLF-safe `VERSION` reads; friendly `--target` errors; escaped
  version match in `release-check`; top-level-anchored no-jq manifest reader;
  `--global` test coverage; de-duplicated/sharpened rule wording.

### Removed
- `ROADMAP.html` — the canonical roadmap is `ROADMAP.md` (Markdown: diffable,
  grep-able, GitHub-native).

## [0.1.0]

Initial Polaris: core rules, generic tooling, and consumer templates.

[Keep a Changelog]: https://keepachangelog.com/
[Semantic Versioning]: https://semver.org/
