# Security Policy

Sentinel is a rules repository; its security surface is **privacy**. See
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md) for the precise guarantee and its
documented limits.

## Reporting

Report a suspected leak, or a flaw in the leak scanner, **privately** to the
maintainer — open a private GitHub security advisory, or contact the owner
directly. Do NOT open a public issue that itself contains the leaked private
term. Private vulnerability reporting is enabled on GitHub so the repository's
**Security and quality → Advisories → Report a vulnerability** flow is the
preferred channel.

GitHub also runs secret scanning with push protection, CodeQL analysis of the
Actions workflow, Dependabot security updates, and dependency review. These
hosted controls complement the repository's full-history Gitleaks scan and
strict cross-platform `ci` gate; they do not replace either one.

## Scope

- **In scope:** a path by which a private term or a machine-local path can reach
  the published tree undetected, or by which the scanner echoes a private term
  to a terminal or CI log.
- **Out of scope:** the residual risks documented in the threat model (unknown
  secrets, encoded content, git history, symlink targets).

## Supported versions

The latest tagged release is supported. Consumers pin a commit/tag and a
`bundle-sha256`; verify with `tools/verify-vendor <dir> <bundle-sha256>`.
