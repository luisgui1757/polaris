# Polaris

**One set of engineering rules that every AI coding assistant follows automatically, in every repo.**

Polaris is a small, language-agnostic rulebook for AI coding tools (Claude Code,
Codex, GitHub Copilot, opencode, pi). You install it once and the rules load
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

## Use it

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
ones that never heard of Polaris — carries the rules. (Per-machine; not shared.)

### 3. Change the rules

Edit a file in `core/`, then re-run `tools/install` (or `--global`). `tools/install --check`
tells you if anything is out of date.

That's it. The three commands above cover everything.

---

## What the AI actually sees

The rules are short and generic — correctness, simplicity, surgical changes,
testing discipline, how modes control edit authority, and memory hygiene. They
live in `core/` and get inlined into the entrypoint your tool auto-loads:

| Tool | File it auto-reads (per repo) | …and globally |
| --- | --- | --- |
| Claude Code | `CLAUDE.md` | `~/.claude/CLAUDE.md` |
| Codex | `AGENTS.md` | `~/.codex/AGENTS.md` |
| GitHub Copilot | `.github/copilot-instructions.md` | *(set in VS Code / github.com — manual)* |
| opencode | `AGENTS.md` | `~/.config/opencode/AGENTS.md` |
| pi | `AGENTS.md` | `~/.pi/agent/AGENTS.md` |

A repo can add its own rules *around* the Polaris block — re-running install only
touches the block, never your text.

---

## Privacy

Polaris is meant to be shareable, so it must never leak your private projects.
The public files only ever contain generic patterns; your private project names
live in `tools/forbidden-terms.local` (gitignored, never committed). `make check`
scans the whole repo and **fails** if a private term or home path slips in — and
it reports the location without ever printing the term.

---

## Develop

```bash
make ci             # the full check: privacy scan + render + drift  (run before pushing)
make install-hooks  # install a git pre-push hook that runs make ci for you
make safeguards     # apply branch protection + merge rules to the GitHub repo
make help           # list everything
```

CI runs the same `make ci` on GitHub (`.github/workflows/ci.yml`); `main` is
protected by the rulesets in `.github/rulesets/` (squash-only, required `ci`
check, linear history).

`ROADMAP.md` tracks remaining work and is deleted once the repo matures.

## License

MIT — see [LICENSE](LICENSE).
