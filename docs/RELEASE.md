# Releasing Polaris

Consumers pin a version and a bundle hash, so releases must be reproducible and
traceable.

1. Land external changes via PR (CI green on the `ci` check). The repo owner may
   direct-push via the intentional ruleset bypass — see `CONTRIBUTING.md`.
2. `CHANGELOG.md`: move the `Unreleased` items under a new `## [x.y.z]` heading,
   and record the **`bundle-sha256`** (the value in the generated adapter header,
   or `polaris_bundle_sha256 core MANIFEST.json`) so consumers can pin it.
3. Bump `VERSION` to `x.y.z`.
4. `make install` — regenerate adapters with the new version stamp.
5. `make ci` — leak scan + render smoke + adapter drift.
6. `make release-check` — asserts `VERSION`, the `CHANGELOG` entry, the adapters,
   and the gate all agree.
7. Tag and push. **Sign it** (`git tag -s`) if you have a signing key configured
   — recommended; otherwise an annotated tag (`git tag -a`) is acceptable:
   ```bash
   git tag -s "vx.y.z" -m "Polaris vx.y.z"   # or: git tag -a (no signing key)
   git push origin "vx.y.z"
   ```
8. Publish a GitHub release from the tag (include the `bundle-sha256`); if also
   distributing artifacts, publish `SHA256SUMS` alongside.

A consumer then pins the tag and verifies its vendored copy:

```bash
tools/verify-vendor <vendor-dir> <bundle-sha256>
```
