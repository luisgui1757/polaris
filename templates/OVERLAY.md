# Consumer Overlay (template)

Copy this file into your repository's overlay directory (for example
`docs/agent/`) and replace the bracketed sections. The overlay specializes or
tightens Polaris for your project. It must not restate Polaris wholesale.

## Project Facts

- [What this project is, and why correctness matters here.]
- [Runtime, data locations, and any live-data risk.]
- [Persisted-data contract, e.g. additive-only with legacy-shape tests.]

## Commands

- [Build / serve / test commands.]
- [The full local gate command, e.g. `make ci`.]

## Adoption Checklist

- [ ] Chosen path is explicit: installed adapters committed to the repo, or
  vendored `core/` + `MANIFEST.json` pinned to a Polaris commit and
  `bundle-sha256`.
- [ ] Drift/integrity gate is documented: `tools/install --check` for installed
  adapters, or `tools/verify-vendor <vendor-dir> <bundle-sha256>` for vendored
  rules.
- [ ] Project overlay does not restate Polaris wholesale; it only adds
  project-specific facts, commands, invariants, and review-ledger locations.
- [ ] Commands in this overlay were run or verified in this repo after adoption;
  stale placeholder commands were removed.
- [ ] Review findings, rejected findings, and assumptions have a durable
  location that future reviewers can append to.
- [ ] Supported AI entrypoints in this repo are listed, with any intentionally
  unsupported surfaces named so missing files are not mistaken for drift.

## Review Ledgers

- [Where findings, rejected findings, and assumptions live.]

## Precedence Note

This overlay layers on top of the vendored Polaris core. If the overlay and
Polaris conflict, the overlay wins only for project-specific scope. Generic
rule changes belong upstream in Polaris, not here.
