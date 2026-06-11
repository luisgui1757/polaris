# Tool Ingestion — how each CLI loads Polaris

Polaris works by inlining its rules into the file each AI CLI already auto-loads
at startup. This is the durable record of *which* file, *where* globally, and the
per-tool gotchas — kept OUT of the injected bundle to protect the token budget.

| Tool | Repo-local (auto-loaded) | Per-user / global | `@import`? |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md`, `.claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | yes |
| Codex | `AGENTS.md` (git root → cwd) | `$CODEX_HOME/AGENTS.md` (`~/.codex`) | no |
| GitHub Copilot | `.github/copilot-instructions.md` (+ `AGENTS.md` in VS Code) | none (UI only) | no |
| opencode | `AGENTS.md` | `~/.config/opencode/AGENTS.md` | no |
| pi | `AGENTS.md` | `~/.pi/agent/AGENTS.md` (`$PI_CODING_AGENT_DIR`) | no |

All five inject their entrypoint into context at startup with **no tool call**.
Polaris **inlines** (does not point) because four of the five have no import
syntax — a pointer would force the agent to re-read files every session.

## Per-tool gotchas

**Claude Code** reads `CLAUDE.md`, NOT `AGENTS.md` (point it with `@AGENTS.md`, or
inline). An *external* `@import` triggers a one-time approval dialog — if
declined it silently disables imports, so inlining is safer for headless runs.
Only ancestor `CLAUDE.md` files load at launch; nested-subdir ones load on
demand. The Agent SDK does not load `CLAUDE.md` unless `settingSources` includes
`'project'`.

**Codex** merges global `~/.codex/AGENTS.md` first, then project root → cwd. The
default cap is 32 KiB (`project_doc_max_bytes`) and content past the budget is
silently truncated — keep the bundle small. Some older builds did not load the
global file; current builds do. `CODEX_HOME` overrides `~/.codex`.

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

**pi** loads the FIRST of `AGENTS.md` > `AGENTS.MD` > `CLAUDE.md` > `CLAUDE.MD`
per directory, walking cwd → root plus `~/.pi/agent`. No import syntax. The
global dir is overridable via `PI_CODING_AGENT_DIR`.

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
  paste the rendered contract (`make render`) and set frontmatter `applyTo: '**'`.
  This lives in your VS Code user profile and applies across workspaces.
- **github.com:** Copilot → profile → *Personal instructions* (affects
  github.com Copilot Chat only — not VS Code or the coding agent).

There is no stable file path to automate either reliably (the VS Code location is
profile- and edition-specific), so this stays a documented manual step.

## Verified (local) versions

Confirmed on the author's machine: Claude Code 2.1.x, Codex CLI 0.137.x, pi
0.78.x. opencode was not installed locally, so its `AGENTS.md` / `~/.config/opencode`
behavior is from its docs — re-confirm with `make status` once it's installed.
