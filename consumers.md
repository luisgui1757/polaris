# Sentinel Consumers

Repositories that adopt Sentinel, by either **installing** (inlining the rules
into native entrypoints with `tools/install`, drift-guarded by `--check`) or
**vendoring** (copying `core/` + `MANIFEST.json` into a vendored directory,
pinning a commit SHA, and verifying the vendored tree against the pin). The
table notes which path each consumer uses.

| Repository | Adoption | Notes |
| --- | --- | --- |
| `sentinel` (this repo) | install (dogfood) | Generates its own `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` via `tools/install`; the `ci` drift check keeps them current. |
| _(your repo)_ | vendor | Copy `core/` + `MANIFEST.json` into `.agent-rules/`, pin a commit SHA, and verify the vendored tree with `tools/verify-vendor`. |

**Verifying a vendored tree.** `verify-vendor` is *not* part of the vendored
payload — you copy only `core/` + `MANIFEST.json`. Run it from an upstream Sentinel
checkout pinned to the same commit SHA:

```bash
path/to/sentinel/tools/verify-vendor .agent-rules <expected-bundle-sha256>
```

It recomputes the bundle hash of your vendored `core/` + `MANIFEST.json` and
fails if the tree is incomplete, the manifest points outside its contained core
layout, optional core files are missing, or the rendered bundle does not match
the pinned hash. The expected hash is required by default; use
`path/to/sentinel/tools/verify-vendor --structure-only .agent-rules` only when
you deliberately want a structure check without integrity proof. (`VERSION` is
optional metadata and is not part of the hash.)

Consumers are listed without exposing private project details. Add a row when a
new repository adopts Sentinel.
