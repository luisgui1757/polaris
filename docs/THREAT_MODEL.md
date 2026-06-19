# Polaris Threat Model

Polaris exists to be *shared* — its rules propagate into every repo and, when
installed globally, into a developer's home configuration. Its one security
promise is **privacy**: nothing private about the author or their other projects
may leak into a tree meant to be published. This document states that guarantee
precisely — what it covers, what it does not, and why.

## Assets

1. **Private project identifiers** — names of the author's other projects,
   product names, internal domains, locale or jargon terms.
2. **Machine-local paths** — absolute home directories and the like.
3. **Rule integrity** — a consumer must be able to trust that the rules it
   inlined are a known, unmodified Polaris release.

Polaris holds no credentials, tokens, or user data; those are not its assets. It
is a rules repository.

## Trust boundary

- **Trusted:** the author's machine, where the gitignored private denylist
  (`tools/forbidden-terms.local`) lives.
- **Published / untrusted:** the committed tree, the GitHub repo, CI logs, and
  any consumer that vendors or installs Polaris.

The boundary is the **commit**: anything that crosses into the committed tree is
treated as public forever (history is not erasable in practice).

## Adversary

The adversary is **mistake**, not malice. The author is trusted; there is no
model for an author exfiltrating their own secrets. Failure modes:

- **Accidental authorship leak** (primary): the author or an AI assistant writes
  a private name or home path into a committed file — a rule, the README, a
  generated adapter, the manifest, or even a file *name*.
- **Diagnostic leak**: the scanner itself echoes a private term into a terminal
  or a public CI log while reporting a hit.
- **Supply-chain drift**: a consumer runs a partial, stale, or modified Polaris
  while believing it pinned a known release.

## Controls

- **Two-tier denylist.** The committed tree carries only generic, publishable
  patterns (`forbidden_core_terms`). Private strings live only in the gitignored
  `tools/forbidden-terms.local`. The public tree therefore never *enumerates*
  what is private — the exact flaw this repo was built to fix.
- **Whole-working-tree scan** (`tools/check`): every tracked and not-yet-tracked
  file (minus gitignored), plus file/dir **names**, plus the **manifest** itself,
  is scanned for both generic patterns and private terms.
- **Redaction.** A private-term hit is reported by `path:line` only — content is
  withheld and any private term in the path is masked — so neither a terminal
  nor a CI log echoes the term or an adjacent secret. Generic patterns are shown
  (public by definition).
- **Fail-closed.** An unreadable path or a grep error fails the scan rather than
  reading as clean.
- **Integrity hash and byte comparison.** Every generated block carries a
  `bundle-sha256`. `tools/status` recomposes the expected adapter body and
  compares the whole managed block, so a tampered body with a current header is
  still reported as stale. `tools/verify-vendor` recomputes the vendored bundle
  hash and requires the pinned expected hash by default, so a consumer can prove
  a vendored tree matches the released rules.

## What is NOT protected (residual risk — read this)

- **Unknown secrets.** The scan matches *known* strings (generic patterns + your
  denylist). A brand-new private term you have not added will pass. The denylist
  is a memory, not a classifier — keep it current. For secret *shapes* (tokens,
  keys) Polaris already integrates **gitleaks** in CI (the `lint` job gated by
  `ci`, scanning full history); note gitleaks matches known secret shapes, not
  your private-term denylist — the two are complementary.
- **Encoded / transformed content.** A private term that is base64'd, hashed, or
  split across lines will not match.
- **Matching gaps.** Pure-word terms match on word boundaries (so a short term
  cannot trip a longer word that merely contains it) and case-sensitively; this
  misses inflections (a plural), case variants, and a term fused into a longer
  identifier without a separator (a codename inside a camelCase token) unless
  you add those forms explicitly. Without `jq`, the manifest reader is also
  best-effort (a bracket inside a term can truncate the generic list).
- **Symlinks.** The content scanner does NOT follow symlinks (their target may be
  outside the repo); a symlink's *name* is still checked. A symlink pointing at a
  secret outside the repo is out of scope by design.
- **Git history.** The scan inspects the working tree, not historical commits. A
  term already committed in history is neither found nor removable by this tool.
- **The denylist file.** The guarantee is void if you force-add
  `tools/forbidden-terms.local` or disable its gitignore.

## Operating rules

- Run `make ci` before ordinary local checks. For push-time proof, run
  `make gate`; `make install-hooks` makes that strict gate automatic before
  every push.
- Add a term to the local denylist the moment a new private project starts —
  before you might mention it.
- Never commit the local denylist; never weaken redaction to print a private
  term "just to debug."
- Treat a green scan as "no *known* leak," not "no leak."
