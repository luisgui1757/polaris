# Codex Review Handoff — gold-standard hardening + Windows install path

Adversarial review handoff. Pick this up from a fresh checkout of `main`.
This file is transient (a review artifact); delete it once the review is closed.

## What to review (be adversarial)

A two-track change driven by a "canonical gold standards, no workarounds or
shortcuts" review. The question for you: **does it actually enforce the gold
standard without introducing new shortcuts or correctness bugs — and is the
Windows installer truly correct on its real target, amd64?**

### Track A — gold-standard hardening
- New rule clauses: `core/TESTING.md` (no weaken/skip/delete a failing test),
  `core/INVARIANTS.md` (no catch-and-discard; satisfy a checker, never silence
  it), `core/EXECUTION.md` (no stub-ship; "calibrate to stakes" bound to blast
  radius), `core/BOOTSTRAP.md` + the `tools/install` render preamble (overlays
  may tighten freely, relax only with explicit justification). Entrypoints
  (`AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md`) are regenerated.
- Strict gates (no silent skip): `POLARIS_STRICT=1` (CI + `tools/release-check`)
  turns a missing linter / `bats` / `pwsh` into a FAILURE; locally a skip is loud
  and named. ShellCheck is blocking via `tools/lint-shell`. The canonical schema
  is enforced by `check-jsonschema`.

### Track B — Windows install path
- `tools/install.ps1`: a PowerShell port of `tools/install`. It MUST render
  byte-identical output to the bash installer (same bundle sha256, LF endings)
  so the adapter drift check agrees across Windows and POSIX. `.gitattributes`
  forces LF on every installer-touched file.

## amd64 is the target — how it is tested

Windows ships on **amd64**. The author's local box is Apple Silicon (arm64), and
an amd64 PowerShell container crashes under qemu emulation, so local arm64 runs
prove only the logic. The binding proof runs on real amd64 hardware in CI:

- `windows` job → `windows-latest` (**amd64**) runs `tools/install.ps1 -Check`:
  proves the renderer is drift-free against the committed entrypoints natively.
- `test (ubuntu-latest)` (**amd64**) runs the bats cross-render parity tests:
  bash-vs-pwsh byte-for-byte `cmp` of `AGENTS.md` / `CLAUDE.md` /
  `.github/copilot-instructions.md`, plus `install.ps1 -Check`.
- Those parity tests are now **strict-required** (`tests/polaris.bats`): under
  `POLARIS_STRICT=1` a missing `pwsh` FAILS the suite instead of silently
  skipping, so amd64 parity coverage can never be lost by coincidence.

The `ci` aggregate requires `test`, `lint`, and `windows` to all pass.

## Specific things to attack
1. `tools/install.ps1` vs `tools/install` / `tools/polaris-lib.sh`: find ANY
   input/environment where pwsh and bash diverge — heading demotion
   (`^#{1,6} ` + code-fence model), per-file trailing-newline handling, the
   embedded-bundle trailing-newline strip, sha256 over UTF-8 LF bytes,
   compose/remove (duplicate-block collapse, unterminated-BEGIN refusal), raw
   (non-normalized) read for the drift compare, empty core file, conflicting
   action switches, Windows path/encoding/execution-policy pitfalls.
2. Strict gates: any path where a check still passes having run nothing?
3. Rule text: new loopholes, contradictions, or a weakened "override"->"floor"?
4. CI: is amd64 parity genuinely enforced, or still coincidental?

## How to verify locally
- `make ci` (strict in CI via `POLARIS_STRICT=1`), `make test`, `make lint-shell`.
- `pwsh tools/install.ps1 -Check` (needs PowerShell 5.1+ / 7+).
- Cross-render: `bash tools/install --target A` and
  `pwsh tools/install.ps1 -Target B`, then compare A and B byte-for-byte.

## State
- `main` is green across `ci` / `windows` / both `test` legs / `lint`.
- The change spans several commits; review `main` as a whole, not one commit.
