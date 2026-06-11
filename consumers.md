# Polaris Consumers

Repositories that adopt Polaris, by either **installing** (inlining the rules
into native entrypoints with `tools/install`, drift-guarded by `--check`) or
**vendoring** (copying `core/` + `MANIFEST.json` into a vendored directory,
pinning a commit SHA, and verifying the vendored tree against the pin). The
table notes which path each consumer uses.

| Repository | Adoption | Notes |
| --- | --- | --- |
| `polaris` (this repo) | install (dogfood) | Generates its own `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` via `tools/install`; the `ci` drift check keeps them current. |
| _(your repo)_ | vendor | Copy `core/` + `MANIFEST.json` into `.agent-rules/`, pin a commit SHA, and verify the vendored tree with `tools/verify-vendor`. |

Consumers are listed without exposing private project details. Add a row when a
new repository adopts Polaris.
