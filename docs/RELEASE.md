# Releasing Polaris

Consumers pin a version and a bundle hash, so releases must be reproducible and
traceable.

1. Land all changes via PR (CI green on the `ci` check).
2. `CHANGELOG.md`: move the `Unreleased` items under a new `## [x.y.z]` heading.
3. Bump `VERSION` to `x.y.z`.
4. `make install` — regenerate adapters with the new version stamp.
5. `make ci` — leak scan + render smoke + adapter drift.
6. `make release-check` — asserts `VERSION`, the `CHANGELOG` entry, the adapters,
   and the gate all agree.
7. Tag and push a **signed** tag:
   ```bash
   git tag -s "vx.y.z" -m "Polaris vx.y.z"
   git push origin "vx.y.z"
   ```
8. If distributing artifacts, publish `SHA256SUMS` alongside the tag.

A consumer then pins the tag and verifies its vendored copy:

```bash
tools/verify-vendor <vendor-dir> <bundle-sha256>
```
