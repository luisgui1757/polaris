# Tool Ingestion — how each CLI loads Sentinel

Sentinel works by inlining its rules into the file each AI CLI already auto-loads
at startup. This is the durable record of *which* file, *where* globally, and the
per-tool gotchas — kept OUT of the injected bundle to protect the token budget.
The machine-readable source for the supported-tool matrix is
[`templates/adapters/tool-metadata.tsv`](../templates/adapters/tool-metadata.tsv);
installer/status/tests validate against that metadata so docs and tooling do not
silently drift.

| Tool | Repo-local (auto-loaded) | Per-user / global | `@import`? | Evidence status |
| --- | --- | --- | --- | --- |
| Claude Code | `CLAUDE.md`, `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | yes | live-verified 2026-06-18 |
| Codex | `AGENTS.md` (project root -> cwd) | `$CODEX_HOME/AGENTS.md` (`~/.codex`) | no | live-verified 2026-06-18 |
| GitHub Copilot | `.github/copilot-instructions.md` and agent `AGENTS.md` | none (UI/profile only) | no | docs-confirmed 2026-06-18 |
| opencode | `AGENTS.md` | `~/.config/opencode/AGENTS.md` | no | docs-confirmed 2026-06-18 |
| Pi CLI | `AGENTS.md` (or `CLAUDE.md`) | `~/.pi/agent/AGENTS.md` (`$PI_CODING_AGENT_DIR`) | no | local-package-confirmed 2026-06-18 |

All five inject their entrypoint into context at startup with **no tool call**.
Sentinel **inlines** (does not point) because four of the five have no import
syntax — a pointer would force the agent to re-read files every session.

## Per-tool gotchas

**Claude Code** reads `CLAUDE.md`, NOT `AGENTS.md` (point it with `@AGENTS.md`, or
inline). An *external* `@import` triggers a one-time approval dialog — if
declined it silently disables imports, so inlining is safer for headless runs.
Only ancestor `CLAUDE.md` files load at launch; nested-subdir ones load on
demand. The Agent SDK does not load `CLAUDE.md` unless `settingSources` includes
`'project'`.

**Codex** reads global guidance from `AGENTS.override.md` or `AGENTS.md` under
`CODEX_HOME` (`~/.codex` by default), then walks from project root to cwd and
uses at most one instruction file per directory. `AGENTS.override.md` takes
precedence over `AGENTS.md`; configured fallback names come after `AGENTS.md`.
`tools/install --global` writes `AGENTS.md` and warns if an existing
`AGENTS.override.md` would shadow it; `tools/status` reports that state as
`overridden`. The default cap is 32 KiB (`project_doc_max_bytes`) and content
past the budget is silently truncated — keep the bundle small.

**GitHub Copilot** has three surfaces with different scopes:
`.github/copilot-instructions.md` works everywhere (web, VS Code, coding agent);
VS Code additionally auto-detects `AGENTS.md` / `CLAUDE.md`; github.com "personal
instructions" are UI-only and do not reach VS Code. There is **no global file** —
set user-wide rules via the VS Code user profile (`*.instructions.md`,
`applyTo: '**'`) and/or github.com personal instructions.

**opencode** treats `AGENTS.md` as canonical; if both `AGENTS.md` and `CLAUDE.md`
exist in one directory, `CLAUDE.md` is ignored there. Extra files can be pulled
via the `opencode.json` `instructions` array (globs + remote URLs) — but a slow
remote URL delays startup, so avoid remote instructions. Global lives under
`~/.config/opencode/`.

**Pi CLI** loads `AGENTS.md` (or `CLAUDE.md`) at startup from its global config
directory, parent directories, and the current directory. No import syntax. The
global dir is overridable via `PI_CODING_AGENT_DIR`, and `--no-context-files`
disables context-file discovery.

## Proving it loaded (manual probe)

Automated ingestion probes are intentionally NOT in CI (model-dependent, flaky,
sometimes paid). To verify locally that a tool actually loaded the rules, start
it in a repo and ask it to quote a distinctive line — e.g. *"Quote the first rule
under the Modes section of your loaded instructions."* If it can, the block is in
context. Claude Code also lists loaded instruction files via `/memory`. (Claude
strips HTML comments, so the `<!-- version … -->` stamp is invisible there — ask
about the rule text, not the marker.) Compare the installed state with
`tools/status`.

## Global Copilot (no file — set it manually)

Copilot has no global dotfile. To carry the rules into every workspace:

- **VS Code:** Command Palette → *Chat: New Instructions File* → *New (User)*;
  paste the brand-neutral contract — the text between the
  `<!-- AGENT-RULES:BEGIN -->` and `<!-- AGENT-RULES:END -->` markers of a
  generated adapter (this repo's `AGENTS.md`, or any target you ran
  `tools/install` on) — and set frontmatter `applyTo: '**'`. (Do not paste
  `make render` output: that debug dump includes the manifest and file layout.)
  This lives in your VS Code user profile and applies across workspaces.
- **github.com:** Copilot → profile → *Personal instructions* (affects
  github.com Copilot Chat only — not VS Code or the coding agent).

There is no stable file path to automate either reliably (the VS Code location is
profile- and edition-specific), so this stays a documented manual step.

## Evidence ledger

Point-in-time snapshot as of 2026-06-18. Treat these as dated confirmations, not
permanent guarantees — CLIs move.

| Tool | Status | Evidence |
| --- | --- | --- |
| Claude Code | live-verified | Local `claude --version` reported 2.1.172. Official docs confirm `CLAUDE.md`, `~/.claude/CLAUDE.md`, project `.claude/CLAUDE.md`, import syntax, and startup loading: <https://code.claude.com/docs/en/memory>. |
| Codex | live-verified | Local `codex --version` reported 0.140.0. Official docs confirm global/project `AGENTS.md`, `CODEX_HOME`, `AGENTS.override.md`, and `project_doc_max_bytes`: <https://developers.openai.com/codex/guides/agents-md>. |
| GitHub Copilot | docs-confirmed | GitHub docs confirm `.github/copilot-instructions.md`, repository `AGENTS.md` agent instructions, automatic use, and no file-based global install path: <https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions>. |
| opencode | docs-confirmed | OpenCode docs confirm `AGENTS.md`, `~/.config/opencode/AGENTS.md`, Claude fallback behavior, precedence, and `opencode.json` instructions; the CLI was not installed locally: <https://opencode.ai/docs/rules>. |
| Pi CLI | local-package-confirmed | Local `pi --version` reported 0.78.1. The installed package README confirms startup loading of `AGENTS.md` or `CLAUDE.md`, global `~/.pi/agent/AGENTS.md`, parent/current-directory loading, `--no-context-files`, and `PI_CODING_AGENT_DIR`. |
