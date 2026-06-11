# Polaris Review Protocol

Reviews are evidence-first.

## Before A Review

- Read the repository entrypoint, Polaris core, and repository overlay.
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

## Ledgers

- Preserve history. Append or change status with justification.
- Record false alarms in the rejected-finding location defined by the
  repository overlay.
- Accepted bugs need tests and documentation updates.
