# Polaris Roadmap

Durable, plaintext roadmap - diffable, grep-able, GitHub-native. Delete at
maturity.

## Review snapshot - 2026-06-18

Scope: all-repo adversarial review of Polaris as a generic baseline rule system
for Claude Code, Codex, GitHub Copilot, opencode/OpenCode, and Pi CLI. This was
a planning/review round only: no implementation code changed.

Evidence gathered:

- Two independent read-only review passes covered contract/docs/adapters and
  installer/check/test/release/security machinery.
- Local gates run:
  - `make ci` passed. It skipped local `check-jsonschema` because the command is
    not installed locally; CI strict mode is expected to require it.
  - `make test` passed: 22/22 bats tests.
- Current repo adapters are drift-free: `tools/install --check` reports
  `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` as `ok`.
- `tools/status` currently reports repo adapters as `current`; global installs
  on this machine are not Polaris-managed (`no-block` for Codex/Claude, absent
  for opencode/Pi).
- Current external docs checked for volatile tool-ingestion assumptions:
  - Codex docs: https://developers.openai.com/codex/guides/agents-md
  - Claude Code docs: https://code.claude.com/docs/en/memory
  - GitHub Copilot docs:
    https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions
  - OpenCode docs: https://opencode.ai/docs/rules

## Implementation snapshot - 2026-06-18

Branch: `review/gold-standard-roadmap`.

The P1/P2/P3 findings below are fixed in this branch. Verification run after the
fixes:

- `bash tools/install --check` passed; generated repo adapters are byte-current.
- `bash tools/ruleset-check` passed against checked-in `.github/rulesets`.
- `check-jsonschema --schemafile schemas/manifest.schema.json MANIFEST.json`
  passed with `check-jsonschema` available on `PATH`.
- `make test` passed: 48/48 bats tests.
- `make ci` passed as local preflight; as designed outside strict mode, it
  skipped local `check-jsonschema` because that binary is not globally installed.
- `make gate` passed with the strict toolchain available on `PATH`: strict
  preflight with schema validation, 48/48 bats tests, and PowerShell adapter
  drift proof.
- `git diff --check` passed.

Not run: live GitHub ruleset verification, global install, or model-dependent
ingestion probes.

## CI repair snapshot - 2026-06-19

PR #1 initially failed GitHub CI on `test (ubuntu-latest)` because Ubuntu's
ShellCheck flagged `SC2015` in `tools/polaris-lib.sh` for the
`cd ... && pwd || true` idiom inside `polaris_check_core`. The fix rewrites that
path resolution as explicit `if` branches and adds a focused regression proving
that a supplied core directory must still match the manifest `core_dir`.

A second Ubuntu-only failure exposed Bash-version drift in `tools/status`: the
`${path/#$HOME/~}` replacement could expand `~` back to `$HOME` on newer Bash.
Status output now formats home-relative paths explicitly.

Verification after the repair:

- `bash tools/lint-shell` passed.
- `bats --filter 'manifest paths' tests/polaris.bats` passed: 3/3.
- `make ci` passed as local preflight.
- `make gate` passed with the strict toolchain available on `PATH`: strict
  preflight with schema validation, 49/49 bats tests, and PowerShell adapter
  drift proof.
- `git diff --check` passed.

## Now (owner actions)

- **Run `make install-global` if desired** to carry the rules into every repo on
  this machine, then re-run `tools/status` and record the expected global state.
- **Decide the verification bar for paid/model-dependent ingestion probes.**
  Some supported surfaces can only be proven by launching the real tool and
  asking what instructions reached context. Keep that out of CI unless the owner
  accepts the cost/flakiness.
- **Run live ruleset verification after any GitHub settings apply** with
  `tools/ruleset-check --repo owner/repo --owner-id <id>` if you want evidence
  against live GitHub state, not only the checked-in JSON.

## Fixed in branch - P1

### Make REVIEW self-contained

Status: fixed in this branch. `core/REVIEW_PROTOCOL.md` is now in
`MANIFEST.json`'s required read order, generated adapters inline the protocol,
and tests fail if generated adapters still reference the old dangling
`deep-review protocol` phrase.

Gap: the injected contract says REVIEW findings use the "deep-review protocol,"
but `core/REVIEW_PROTOCOL.md` is optional and normal `tools/install` output does
not include it. Installed consumers therefore get a dangling reference for one
of the highest-stakes modes.

Evidence:

- `core/MODES.md` references the deep-review protocol.
- `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` repeat that
  reference inside the generated bundle.
- `core/REVIEW_PROTOCOL.md` contains the actual finding schema, but it is listed
  under `optional_core_files` in `MANIFEST.json`.

Proposed solution:

- Inline a compact review finding schema into the required bundle, or install /
  vendor `REVIEW_PROTOCOL.md` wherever REVIEW mode references it.
- Add a drift test that generated adapters do not reference unavailable optional
  files.

Acceptance criteria:

- A fresh target repo installed with only `tools/install --target <repo>` gives
  an agent enough information to perform a REVIEW without reading any missing
  Polaris file.
- Tests fail if required bundle text mentions a Polaris file that is neither
  inlined nor installed.

### Harden release provenance

Status: fixed in this branch. `tools/release-check` now requires a clean
index/worktree with no untracked files, rejects existing local/checkable remote
tags, verifies the exact current `bundle-sha256` in the matching changelog
section by exact bracketed `x.y.z` heading outside fenced blocks, rejects
duplicate release sections or bundle-hash entries, prints the certified commit,
and `polaris_bundle_sha256` fails closed without relying on caller `pipefail`.

Resolved gap: `make release-check` previously could certify a release without
proving the exact published `bundle-sha256`, without proving the tree is clean,
and while the documented hash helper could fail open outside `pipefail`. A later
audit also found the changelog section match was too loose: `VERSION=1.2.3`
could match a `[11.2.3]` heading, non-`x.y.z` version tokens were not rejected,
and ambiguous duplicate sections or bundle-hash entries were not rejected.

Historical evidence:

- `docs/RELEASE.md` requires recording the `bundle-sha256`.
- `tools/release-check` checked only that a changelog section for `VERSION`
  existed, then ran install/CI/tests.
- `tools/release-check` printed "safe to tag" without checking staged changes,
  unstaged changes, untracked files, existing `v$VERSION` tags, or the exact
  commit being certified.
- Verified locally: `polaris_render_bundle core /dev/null` exits 1, but
  `polaris_bundle_sha256 core /dev/null` emitted the empty SHA and exited 0 in a
  plain shell before the fix.
- Audit reproduction: the old changelog heading regex could match
  `VERSION=1.2.3` against `## [11.2.3]`.
- Audit reproduction: release-check accepted non-`x.y.z` `VERSION` values,
  fenced fake headings, duplicate release sections, and duplicate bundle hashes.

Implemented solution:

- Make `release-check` compute the current bundle hash, parse the matching
  changelog version section by exact bracketed `x.y.z` heading outside fenced
  blocks, and fail unless exactly one matching hash appears there.
- Make `release-check` fail unless the index and working tree are clean and no
  non-ignored untracked files exist.
- Print the exact commit SHA being certified and fail if `v$VERSION` already
  exists locally or remotely.
- Make `polaris_bundle_sha256` fail closed internally, independent of caller
  shell options.

Acceptance criteria:

- Wrong or missing changelog bundle hash fails a regression test.
- A sibling heading such as `[11.2.3]` cannot satisfy `VERSION=1.2.3`.
- Non-`x.y.z` versions, fenced fake headings, duplicate release sections, and
  duplicate bundle-hash entries fail.
- Dirty, staged, or untracked release trees fail.
- An invalid manifest never produces a successful SHA helper result.

### Harden `tools/status` integrity

Status: fixed in this branch. `tools/status` now recomposes the expected adapter
body and compares the full managed block; a tampered body with a current header
reports `STALE`.

Gap: `tools/status` can report `current` for a tampered adapter body if the
stored header hash is unchanged. It currently proves header freshness, not body
integrity.

Evidence:

- `tools/status` reads the first generated `sha256:` header and compares it to
  the current bundle hash.
- `tools/install --check` performs the stronger body comparison.
- Verified locally: after modifying the body of a generated `AGENTS.md` in a
  temp target while leaving the header intact, `tools/status --target <tmp>`
  reported `current`; `tools/install --target <tmp> --check` reported `DRIFT`.
- `docs/THREAT_MODEL.md` currently says `tools/status` helps consumers confirm
  exactly which rendered rules they have.

Proposed solution:

- Make `tools/status` reuse the same compose-and-compare path as
  `tools/install --check`, or relabel its result as header-stamp status only.
- Update threat-model and ingestion docs so exact rendered-rule proof points to
  body comparison.

Acceptance criteria:

- A stale body with a current header reports stale/drift, not `current`.
- Documentation distinguishes header metadata from full byte-for-byte proof.

### Add semantic ruleset verification

Status: fixed in this branch. `tools/ruleset-check` validates local/exported
ruleset JSON and optional live GitHub rulesets for the required main-branch
semantics, and `scripts/apply-repo-safeguards.sh` runs it before and after live
application.

Gap: `scripts/apply-repo-safeguards.sh` prints "applied and verified" after
checking repo merge settings, ruleset existence, and bypass actors, but it does
not verify the actual rule semantics that protect `main`.

Evidence:

- The script upserts `.github/rulesets/*.json`.
- Post-apply checks confirm ruleset IDs and owner bypass actors.
- It does not verify live `enforcement=active`, `refs/heads/main`, strict
  required `ci`, squash-only PRs, code-owner review, last-push approval, thread
  resolution, linear history, deletion protection, or non-fast-forward
  protection.

Proposed solution:

- Add `tools/ruleset-check` or a safeguards verifier mode that validates both
  local JSON and live GitHub rulesets structurally.
- Parse JSON with `jq`; reject duplicate/unknown/missing rule semantics instead
  of relying on text greps.

Acceptance criteria:

- A weakened local or live ruleset fails the verifier.
- The verifier can run read-only and reports exactly which required semantic is
  missing.

## Fixed in branch - P2

### Enforce manifest path containment and complete core structure

Status: fixed in this branch. Tooling now resolves `core_dir` from
`MANIFEST.json`, rejects absolute/parent/unsafe paths, requires declared
optional core files, mirrors the constraints in JSON Schema, and covers the
behavior in bats.

Gap: `MANIFEST.json` declares `core_dir` and optional core files, but tooling
still hard-codes `core` in places and does not fully prove that declared paths
are contained in the vendored payload.

Evidence:

- `MANIFEST.json` declares `core_dir`.
- `tools/install` and `tools/verify-vendor` hard-code `core`.
- `polaris_check_core` checks required files but not every optional file listed
  in `optional_core_files`.
- The JSON schema accepts arbitrary strings for required/optional core paths.

Proposed solution:

- Resolve `core_dir` from `MANIFEST.json` everywhere.
- Require all listed optional files to exist.
- Reject absolute paths and `..` segments for `core_dir`, required files,
  optional files, and `local_denylist`.
- Enforce that required and optional core files normalize under `core_dir`.
- Mirror constraints in JSON Schema and bats tests.

Acceptance criteria:

- `verify-vendor` fails if an optional declared core file is missing.
- A manifest that points outside the vendor root or outside `core_dir` fails
  before rendering or hashing.

### Require vendor integrity by default

Status: fixed in this branch. `tools/verify-vendor` now requires an expected
hash by default; the old non-integrity path is explicit
`--structure-only` and is documented as such.

Gap: `tools/verify-vendor` exits 0 without an expected hash, even though it
warns that integrity is not proven.

Evidence:

- Usage allows `[expected-bundle-sha256]`.
- Without the hash, the tool prints `INTEGRITY NOT PROVEN` and exits
  successfully.

Proposed solution:

- Require the expected bundle hash by default.
- Add an explicit `--structure-only` flag for the current warning-and-zero
  behavior.
- Update docs and examples so CI usage always passes the pinned hash.

Acceptance criteria:

- Running `tools/verify-vendor <dir>` without a hash fails.
- Running `tools/verify-vendor --structure-only <dir>` succeeds only for
  structure checks and labels the result as non-integrity proof.

### Canonicalize adapter/tool metadata

Status: fixed in this branch. `templates/adapters/tool-metadata.tsv` is the
canonical supported-tool matrix; install/status helpers and tests read or
validate against it, and README/tool-ingestion docs point to it.

Gap: the supported-tool matrix is duplicated across docs, installer, status, and
tests. `MANIFEST.json` is described as the machine-readable contract but does
not contain adapter target metadata.

Evidence:

- Adapter paths are duplicated in `docs/tool-ingestion.md`, `tools/install`,
  `tools/status`, and `tests/polaris.bats`.
- Current Codex docs now include `AGENTS.override.md` precedence and explicit
  global confirmation commands, which are not represented in the repo's
  machine-readable metadata.
- Current Copilot docs support `.github/copilot-instructions.md` and also
  `AGENTS.md` agent instructions; Polaris currently writes the former and the
  root `AGENTS.md`, but the support model is not recorded as data.
- Current OpenCode docs confirm `AGENTS.md`, global
  `~/.config/opencode/AGENTS.md`, Claude fallback behavior, and an
  `opencode.json` `instructions` array.

Proposed solution:

- Add a manifest-backed or generated tool-entrypoint matrix covering repo-local
  path, global path, import support, fallback/override names, install behavior,
  and verification status.
- Generate or validate README/tool-ingestion/install/status/tests from that
  matrix.

Acceptance criteria:

- Adding or changing a tool target requires changing one canonical metadata
  source.
- Tests fail if docs, installer, status, or tests drift from that source.

### Add a dated ingestion evidence matrix and probes

Status: fixed for the evidence matrix and docs claims in this branch; live
model-dependent probes remain an owner decision. README and tool-ingestion docs
now distinguish `live-verified`, `docs-confirmed`, and
`local-package-confirmed` instead of overstating the proof level.

Gap: the docs blur live-verified behavior, docs-only behavior, and unverified
assumptions. The central product promise is automatic startup ingestion; that
promise needs evidence by tool and surface.

Evidence:

- `README.md` says only opencode is unverified and the other four are confirmed.
- `docs/tool-ingestion.md` says all five inject at startup, but its dated
  snapshot lists Claude Code, Codex, and Pi, and says opencode was docs-only.
- Copilot live confirmation is not recorded in repo evidence.
- Pi CLI is installed on this machine, but `pi --version` and `pi --help` did
  not produce useful output in this review; public source evidence was not found
  in the quick pass.

Proposed solution:

- Create a table with statuses: `verified-live`, `docs-confirmed`,
  `unverified`, or `manual-only`.
- Store version, date, exact probe, expected answer, and any cost/flakiness
  reason for excluding the probe from CI.
- Downgrade README claims until every named surface has either a live proof or a
  clearly labeled docs-only status.

Acceptance criteria:

- Each supported tool has an auditable evidence row.
- Claims in README never exceed the matrix status.

### Split local preflight from required gate

Status: fixed in this branch. `make preflight` names the fast local surface,
`make ci` is a compatibility alias, `make gate` runs the strict local proof, and
the pre-push hook runs `make gate`.

Gap: the local pre-push hook is described as mirroring GitHub `ci`, but it runs
only `tools/ci`. GitHub required `ci` aggregates OS tests, strict lint, and the
native Windows installer check.

Evidence:

- `tools/install-hooks` says it mirrors GitHub `ci`.
- The generated hook runs `tools/ci`.
- `tools/ci` runs check/render/drift/lint/shellcheck, not `make test`.
- GitHub separately runs `make test`, strict lint, and Windows PowerShell
  checks before the aggregate `ci`.

Proposed solution:

- Either make the hook run the same practical required surface where available,
  or rename/document `tools/ci` as a local preflight.
- Add a separate `make gate` for the strongest local equivalent of required CI:
  `POLARIS_STRICT=1 make ci`, `POLARIS_STRICT=1 make test`, and Windows parity
  where `pwsh` is available.

Acceptance criteria:

- Docs no longer say the pre-push hook mirrors GitHub unless it actually does.
- Contributors can run one clearly named command for the strongest local gate.

### Make local lint either clean or explicitly non-blocking by policy

Status: fixed in this branch. Local preflight is documented as preflight rather
than full proof; `make gate` is the strict local gate; workflow line-length
warnings were removed and `.yamllint` now treats line length as an error.

Gap: `make ci` passed locally while `yamllint` emitted line-length warnings and
`check-jsonschema` skipped because the command is absent. The skip is labeled,
but "passed with warnings/skips" is still weaker than the gold-standard posture.

Evidence:

- Local `make ci` emitted three `yamllint` line-length warnings in
  `.github/workflows/ci.yml`.
- `.yamllint` sets line-length to warning, not error.
- `tools/lint` skips missing tools outside strict mode.

Proposed solution:

- Decide whether local `make ci` is intentionally a fast preflight or should be
  a no-warning full gate.
- If it remains a preflight, rename/docs should make that explicit and point to
  `make gate` for strict local proof.
- If it becomes a full gate, make lint warnings fail or wrap long workflow lines
  so warnings disappear.

Acceptance criteria:

- A local "passed" result cannot be mistaken for "all required checks ran with
  no warnings" unless that is true.

## Fixed in branch - P3

### Make PowerShell writes crash-safe

Status: fixed in this branch. `tools/install.ps1` writes through a
target-directory temp file and atomic replace/move, with regression coverage for
preserving surrounding text and refusing malformed blocks unchanged.

Gap: the bash installer writes via temp file and atomic move; the PowerShell
installer writes directly with `WriteAllText`.

Evidence:

- `tools/install` composes to a temp file in the target directory and final
  moves it into place.
- `tools/install.ps1` writes generated content directly.

Proposed solution:

- Port the bash atomic-write pattern to PowerShell: compose to a temp file in
  the target directory, byte-compare, then atomically replace/move.
- Add a practical regression around preserving surrounding text on write
  failure or malformed blocks.

Acceptance criteria:

- Interruption or write failure cannot leave a partially rewritten adapter when
  the original file was intact.

### Reconcile stale documentation wording

Status: fixed in this branch. README, CONTRIBUTING, RELEASE, tool-ingestion,
consumers, threat-model, and changelog wording now distinguish local preflight,
strict local gate, GitHub aggregate checks, exact status body comparison, and
hash-required vendor verification.

Gap: documentation still contains wording that is true only historically or is
easy to misread.

Evidence:

- `CHANGELOG.md` says ShellCheck was added as advisory in the same release that
  later says ShellCheck is blocking.
- `README.md` says GitHub CI runs the same `make ci` and sets strict mode, while
  the workflow actually runs non-strict `make ci` in the OS matrix and strict
  checks in separate jobs.

Proposed solution:

- Reword changelog and README so historical transitions are unambiguous.
- Keep the distinction between local preflight, strict local gate, and required
  GitHub aggregate explicit.

Acceptance criteria:

- A reader can tell exactly what `make ci`, `make test`, `make release-check`,
  and the GitHub `ci` aggregate prove.

### Expand consumer onboarding from template to proof path

Status: fixed in this branch. `templates/OVERLAY.md` now includes an adoption
checklist for install vs vendor choice, pinned hash/integrity proof, drift gate,
overlay de-duplication, verified commands, review-ledger location, and supported
entrypoints.

Gap: `templates/OVERLAY.md` is useful but minimal. It tells consumers what to
fill in, but does not provide a checklist that proves their overlay avoids
policy duplication, stale commands, and missing verification.

Evidence:

- `templates/OVERLAY.md` has placeholders for project facts, commands, review
  ledgers, and precedence.
- `consumers.md` still lists only this repo plus a placeholder.

Proposed solution:

- Add a consumer adoption checklist: install vs vendor choice, pinned hash,
  adapter drift gate, overlay-dedup expectations, command verification, and
  review-ledger location.
- Add real external consumers only when they can be named without exposing
  private project details.

Acceptance criteria:

- A new repo can adopt Polaris and prove installation/vendor integrity without
  interpreting scattered docs.

## Design decisions and rejected findings

Design decisions and rejected review findings that should not be re-litigated
live in [`reviews/AUDIT_NOTES.md`](reviews/AUDIT_NOTES.md).

## Shipped

Auto-ingestion installer (`--target` / `--global` / `--check` / `--remove`);
brand-neutral, single-axis core (MODES -> INVARIANTS -> EXECUTION -> WORKFLOW ->
TESTING -> MEMORY); two-tier privacy with redaction + path/manifest scans, plus
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
