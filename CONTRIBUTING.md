# Contributing to Polaris

Polaris is small on purpose. A rule here is injected into the context of every AI
session in every repo that installs it — so each rule competes for scarce model
attention and tokens. The bar for adding or changing one is therefore high.

## The rule-admission bar

A rule may live in `core/` only if it is ALL of:

1. **Generic.** It applies to essentially any software project. No language,
   framework, library, tool, or domain specifics — those belong in a consumer's
   own overlay, never in Polaris.
2. **First-principles.** It states a durable engineering principle, not a passing
   fashion or a personal stylistic preference.
3. **Actionable and verifiable.** An agent can tell whether it followed the rule.
   Prefer "run the verification before claiming done" over "write good code."
4. **Non-redundant.** It is not already implied by another rule. Two overlapping
   rules should be merged, not both kept.
5. **Worth its tokens.** The injected bundle is byte-budgeted
   (`render_budget_bytes`). A rule must earn its place against that ceiling; if
   it pushes the bundle over budget, something else must go.

If a candidate fails any of these, it does not go in core. Process or
tool-specific guidance that is not an always-on rule belongs in `docs/`, not the
bundle.

## Changing rules

- Edit `core/*.md`, then `make install` (regenerate adapters with the new version
  stamp) and `make ci` (local preflight: leak scan, render, drift, rulesets,
  lint, ShellCheck) — both must pass.
- Keep `core/` free of project names, private paths, and machine-local state;
  `make check` enforces this (see `docs/THREAT_MODEL.md`).
- Update `CHANGELOG.md` for any change to the rules or the contract; consumers
  pin versions.

## Commits and PRs

- Conventional commit subjects (`feat:`, `fix:`, `chore:`, `docs:`, `review:`),
  imperative mood, ≤72 chars.
- One concern per commit where practical.
- External contributions land via PR; `main` is protected for everyone but the
  owner — squash-only merge, linear history, required `ci` check, mandatory
  code-owner review (see `.github/rulesets/`). The repo owner holds an
  intentional `always` bypass to push directly (by design; see `ROADMAP.md`), so
  not every commit on `main` came through a PR.

## Local setup

```bash
make install-hooks   # pre-push hook that runs the strongest local gate
make ci              # fast local preflight
make gate            # strict local gate: preflight + bats + pwsh drift check
make test            # bats tooling suite (incl. bash/pwsh byte-identity parity)
```

The required GitHub `ci` context is stronger than local preflight: it runs Linux
+ macOS preflight and tests, strict lint with all linters installed, and the
PowerShell installer on a native Windows (amd64) job. `make gate` is the closest
local equivalent and requires the strict local toolchain, including `pwsh`; it
still cannot prove native Windows behavior on a non-Windows host.

## Credits

`core/EXECUTION.md` distills language-agnostic guidance from Andrej Karpathy's
observations on common LLM coding pitfalls.
