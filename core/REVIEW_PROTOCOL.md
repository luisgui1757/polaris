# Review Protocol

Reviews are evidence-first. Apply this protocol whenever REVIEW mode is active,
including generated installs that inline the core contract.

## Before A Review

- Read the active repository entrypoint and repository overlay. If the repo uses
  a vendor or pointer setup instead of an inlined generated entrypoint, read the
  vendored core files named by its manifest.
- Read the requested review prompt and any local ledgers or rejected-finding
  lists.
- Re-validate prior open findings before hunting for new ones.

## Findings

Every finding should include:

- Severity.
- Exact location.
- Concise statement of wrong behavior.
- Reproduction, trace, or proof.
- Source of truth.
- Multi-location check.
- Recommended fix.
- Confidence.

Lead with material findings, ordered by severity. If there are no material
findings, say so directly and name any test or verification gaps that remain.

## Ledgers

- Preserve history. Append or change status with justification.
- Record false alarms in the rejected-finding location defined by the
  repository overlay.
- Accepted bugs need tests and documentation updates.
