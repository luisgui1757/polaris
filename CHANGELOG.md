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
- Branch-protection: the owner's ruleset bypass is now `always` (was
  `pull_request`), so the owner can push directly to `main` (no PR) and override
  `ci`/review; non-owners stay fully gated (PR + code-owner review + strict
  `ci`). Source files, `settings.yml`, and the safeguards verifier updated to
  match. Kept in public by design — avoids leaking WIP into public PR diffs.

### Security
- CI supply-chain hardening (public-launch audit): the `lint` job now downloads
  editorconfig-checker and gitleaks, verifies each against a pinned asset
  `sha256` (`sha256sum -c`), and only then extracts — a yanked/retagged/tampered
  upstream release fails loudly instead of executing. `actions/checkout` is
  pinned to a commit SHA (`@08eba0b… # v4.3.0`). `allow_auto_merge: false` added
  to `settings.yml` so the declarative config matches the safeguards script.

### Fixed
- `tools/verify-vendor`: reading an absent `VERSION` leaked a shell
  "No such file" to stderr while still exiting 0 on a structurally incomplete
  vendor; it now reads `VERSION` only when present (it is optional metadata, not
  part of the bundle hash).
- Docs accuracy (public-launch audit): `tool-ingestion.md` points Copilot users
  at the brand-neutral `AGENT-RULES` marker block, not the `make render` debug
  dump (which prints the manifest/layout), and dates the "verified versions"
  snapshot; `THREAT_MODEL.md` states gitleaks is already integrated (not
  roadmap); `consumers.md` shows the exact `verify-vendor` invocation; `README`
  clarifies that the private-term denylist is owner-local.
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
- CI on public Actions: bumped pinned editorconfig-checker to v3.7.0 (the old
  v2.7.2 release asset 404s upstream); bats end-to-end `check` tests give their
  fixture commit an explicit git identity (`-c user.email/user.name`) so they
  pass on runners with no derivable ident (GitHub `ubuntu-latest`).

### Removed
- `ROADMAP.html` — the canonical roadmap is `ROADMAP.md` (Markdown: diffable,
  grep-able, GitHub-native).

## [0.1.0]

Initial Polaris: core rules, generic tooling, and consumer templates.

[Keep a Changelog]: https://keepachangelog.com/
[Semantic Versioning]: https://semver.org/
