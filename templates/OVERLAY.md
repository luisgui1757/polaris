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

## Review Ledgers

- [Where findings, rejected findings, and assumptions live.]

## Precedence Note

This overlay layers on top of the vendored Polaris core. If the overlay and
Polaris conflict, the overlay wins only for project-specific scope. Generic
rule changes belong upstream in Polaris, not here.
