# Releasing Sentinel

Consumers pin a version and a bundle hash, so releases must be reproducible and
traceable.

1. Land the release change via PR. The exact PR head must have green `ci` and
   CodeQL evidence; integrity has no owner bypass.
2. `CHANGELOG.md`: move the `Unreleased` items under a new `## [x.y.z]` heading,
   and record the **`bundle-sha256`** so consumers can pin it — read it from the
   generated adapter header, or recompute with
   `bash -c 'source tools/sentinel-lib.sh; sentinel_bundle_sha256 core MANIFEST.json'`.
3. Bump `VERSION` to `x.y.z`.
4. `make install` — regenerate adapters with the new version stamp.
5. `make ci` — local preflight: leak scan, render smoke, adapter drift,
   ruleset and repository-policy semantics, lint, and ShellCheck.
6. `make release-check` — requires a clean index/worktree with no untracked
   files, rejects an already-existing `v$VERSION` tag locally or on `origin`,
   fails if the remote tag state cannot be checked, verifies the exact current
   `bundle-sha256` in the matching `CHANGELOG.md` section, and prints the
   certified commit after the adapters, CI gate, and bats suite pass.
7. After the PR lands, update a clean local `main`, confirm local `HEAD` equals
   GitHub's `main`, and re-run `make release-check`. A feature-branch result or
   an earlier revision is not release evidence.
8. Confirm `gh api repos/luisgui1757/sentinel/immutable-releases --jq .enabled`
   returns `true`. Tag and push. **Sign it** (`git tag -s`) if you have a signing
   key configured
   — recommended; otherwise an annotated tag (`git tag -a`) is acceptable:
   ```bash
   git tag -s "vx.y.z" -m "Sentinel vx.y.z"   # or: git tag -a (no signing key)
   git push origin "vx.y.z"
   ```
9. Create and fully verify the release as a draft. Include the
   `bundle-sha256`; if distributing artifacts, publish `SHA256SUMS` alongside
   and verify the downloaded assets through the consumer path. Publish only
   after that proof: immutable releases prevent later tag or asset correction.

A consumer then pins the tag and verifies its vendored copy:

```bash
tools/verify-vendor <vendor-dir> <bundle-sha256>
```

Use `tools/verify-vendor --structure-only <vendor-dir>` only for an explicit
non-integrity audit; normal vendor verification requires the pinned hash.
