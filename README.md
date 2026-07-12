# Sentinel

**One set of engineering rules that every AI coding assistant follows automatically, in every repo.**

Sentinel is a small, language-agnostic rulebook for AI coding tools (Claude Code,
Codex, GitHub Copilot, opencode, Pi CLI). You install it once and the rules load
themselves at startup — no slash command, no "please read the docs," no copy-paste.

---

## The idea in one picture

```
core/  (the rules)  ──►  tools/install  ──►  AGENTS.md / CLAUDE.md / copilot-instructions.md
                                              (the files your AI tool already reads on startup)
```

Your AI tool already auto-reads a special file when it starts. `tools/install`
writes the rules into that file. That's the whole trick.

---

## Get it

```bash
git clone https://github.com/luisgui1757/sentinel.git
cd sentinel
```

Run everything below from that checkout. (Prefer to vendor a pinned copy instead
of installing? See [`consumers.md`](consumers.md).)

---

## Use it

> Run these from your Sentinel checkout — the commands use the repo-relative
> `tools/install` (or `make install`). **On Windows**, use the PowerShell port,
> which behaves identically and renders byte-for-byte the same block:
> `pwsh tools/install.ps1 -Target C:\path\to\repo` (`-Global`, `-Check`,
> `-Remove`, `-DryRun` mirror the bash flags).

### 1. Add the rules to a repo (and share with your team)

```bash
tools/install --target /path/to/your/repo
```

This writes `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` into
that repo. **Commit them.** Now anyone who clones it and opens any AI tool gets
the rules — automatically.

### 2. Add the rules to *everything* on your machine (just you)

```bash
tools/install --global
```

Writes the rules into your home config once. Now **every** repo you open — even
ones that never heard of Sentinel — carries the rules. (Per-machine; not shared.)

### 3. Change the rules

Edit a file in `core/`, then re-run `tools/install` (or `--global`).

### 4. Check, verify, or remove

```bash
tools/install --check    # are the blocks up to date? (drift check; used in CI)
make status              # where are the rules installed?
tools/install --remove   # uninstall — keeps any text you wrote around the block
```

To confirm a tool actually *loaded* the rules, ask it in chat: *"What does your
loaded contract say under Modes?"* If it can answer, the block is in context.

---

## What the AI actually sees

The rules are short and generic — correctness, simplicity, surgical changes,
testing discipline, how modes control edit authority, and memory hygiene. They
live in `core/` and get inlined into the entrypoint your tool auto-loads:

| Tool | File it auto-reads (per repo) | …and globally | Evidence |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md` | `~/.claude/CLAUDE.md` | live-verified 2026-06-18 |
| Codex | `AGENTS.md` | `~/.codex/AGENTS.md` (`$CODEX_HOME`) | live-verified 2026-06-18 |
| GitHub Copilot | `.github/copilot-instructions.md` | *(set in VS Code / github.com — manual)* | docs-confirmed 2026-06-18 |
| opencode | `AGENTS.md` | `~/.config/opencode/AGENTS.md` | docs-confirmed 2026-06-18 |
| Pi CLI | `AGENTS.md` | `~/.pi/agent/AGENTS.md` (`$PI_CODING_AGENT_DIR`) | local-package-confirmed 2026-06-18 |

The canonical tool/adapter metadata lives in
[`templates/adapters/tool-metadata.tsv`](templates/adapters/tool-metadata.tsv);
[`docs/tool-ingestion.md`](docs/tool-ingestion.md) records the source evidence
behind each dated status.

A repo can add its own rules *around* the Sentinel block — re-running install only
touches the block, never your text.

---

## Privacy

Sentinel is meant to be shareable, so it must never leak your private projects.
`make check` scans the whole repo and **fails** if a private term or home path
slips in, reporting the location without ever printing the term. The shipped
files only ever contain generic patterns (home paths); your *own* private project
names live in `tools/forbidden-terms.local` — gitignored, never committed, and
wired in via `MANIFEST.json`'s `local_denylist` key. Create it (one term per
line) to scan for your terms too. Full guarantee and limits:
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md).

---

## Repository layout

| Path | What's there |
| --- | --- |
| `MANIFEST.json` | the machine-readable contract: core read-order, term policy, byte budget — **start here** |
| `core/` | the rules themselves (read in the order `MANIFEST.json` → `required_core_read_order`) |
| `tools/` | installer (`install`, `install.ps1`) + checks (`check`, `ci`, `lint`, `render`, `ruleset-check`, `status`, `verify-vendor`) |
| `scripts/` | one-shot repo safeguards (branch protection) |
| `docs/` | threat model, per-tool ingestion notes, release process |
| `templates/` | overlay + adapter templates and canonical tool metadata for consumers |
| `schemas/` | JSON Schema for `MANIFEST.json` |
| `tests/` | the bats regression suite |
| `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` | **generated** rule blocks (this repo dogfooding its own installer) — don't hand-edit |

**Working on the rules?** Edit `core/`, run `tools/install`, commit the
regenerated adapters. **Just reading?** `MANIFEST.json` + the files it lists are
the whole rulebook.

---

## Develop

```bash
make ci             # local preflight: privacy scan + render + drift + rulesets + lint + shellcheck
make preflight      # same local preflight, named for what it proves
make gate           # strongest local gate: strict preflight + tests + pwsh drift check
make test           # bats tooling suite (incl. the bash/pwsh byte-identity parity)
make install-hooks  # install a git pre-push hook that runs make gate for you
make safeguards     # apply branch protection + merge rules to the GitHub repo
make help           # list everything
```

Local `make ci`/`make preflight` is the fast pre-push surface. It runs the leak
scan, render smoke, adapter drift, semantic ruleset verification, lint, and
ShellCheck; outside strict mode, missing optional linters are skipped loudly and
named in the output. `make gate` is the strongest local proof: it runs the
preflight in strict mode, the bats suite, and the PowerShell drift check; it
requires the strict local toolchain, including `pwsh`.

GitHub's required `ci` context is stronger than local preflight: the workflow
runs Linux + macOS preflight and `make test`, a strict lint job with every
linter installed, and a native **Windows (amd64)** PowerShell installer check.
`main` is protected by the rulesets in `.github/rulesets/` (squash-only,
required `ci` check, linear history).

`ROADMAP.md` tracks remaining work and is deleted once the repo matures.

## License

MIT — see [LICENSE](LICENSE).
