#!/usr/bin/env bats
# Polaris tooling regression tests. Run via `tests/run.sh` or `bats tests`.
# Hermetic: scan tests use a fixture manifest + denylist (the real denylist is
# gitignored and absent in CI); install tests use the repo's real core.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  # shellcheck source=../tools/polaris-lib.sh
  source "$ROOT/tools/polaris-lib.sh"
  TMP="$(mktemp -d)"
  cat > "$TMP/MANIFEST.json" <<'JSON'
{
  "schema_version": 1,
  "name": "polaris",
  "core_dir": "core",
  "required_core_read_order": ["core/INVARIANTS.md"],
  "forbidden_core_terms": ["GENPATH"],
  "local_denylist": "denylist.local",
  "render_budget_bytes": 32768
}
JSON
  printf 'SECRETPROJ\nalpha\nalpha-beta\n' > "$TMP/denylist.local"
  FM="$TMP/MANIFEST.json"
}
teardown() { rm -rf "$TMP"; }

scan() { bash -c "source '$ROOT/tools/polaris-lib.sh'; $1 2>&1"; }

make_release_fixture() {
  rel="$TMP/release-fixture"
  mkdir -p "$rel/tools" "$rel/tests" "$rel/core"
  cp -R "$ROOT/core/." "$rel/core/"
  cp "$ROOT/MANIFEST.json" "$rel/MANIFEST.json"
  cp "$ROOT/tools/polaris-lib.sh" "$ROOT/tools/release-check" "$rel/tools/"
  printf '0.1.0\n' > "$rel/VERSION"
  rel_sha="$(bash -c "source '$ROOT/tools/polaris-lib.sh'; polaris_bundle_sha256 '$rel/core' '$rel/MANIFEST.json'")"
  cat > "$rel/CHANGELOG.md" <<EOF
# Changelog

## [0.1.0] - 2099-01-01

**bundle-sha256:** \`$rel_sha\`
EOF
  printf '#!/usr/bin/env bash\nprintf "install %%s\\n" "$*" >> release-gates.log\nexit 0\n' > "$rel/tools/install"
  printf '#!/usr/bin/env bash\nprintf "ci\\n" >> release-gates.log\nexit 0\n' > "$rel/tools/ci"
  printf '#!/usr/bin/env bash\nprintf "tests\\n" >> release-gates.log\nexit 0\n' > "$rel/tests/run.sh"
  chmod +x "$rel/tools/install" "$rel/tools/ci" "$rel/tests/run.sh"
  ( cd "$rel" && git init -q && git add -A \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm init >/dev/null 2>&1 )
}

commit_release_fixture_change() {
  ( cd "$rel" && git add -A \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm fixture-change >/dev/null 2>&1 )
}

@test "manifest_value reads the name" {
  run polaris_manifest_value "$FM" name
  [ "$status" -eq 0 ]
  [ "$output" = "polaris" ]
}

@test "forbidden_terms merges generic (M) and private (L)" {
  run polaris_forbidden_terms "$FM"
  [[ "$output" == *"M"*"GENPATH"* ]]
  [[ "$output" == *"L"*"SECRETPROJ"* ]]
}

@test "scan: a clean file passes" {
  echo "nothing private here" > "$TMP/clean.md"
  run scan "polaris_scan_terms '$FM' '$TMP/clean.md'"
  [ "$status" -eq 0 ]
}

@test "scan: private hit fails, redacts the term AND adjacent secrets (location-only)" {
  printf 'leak SECRETPROJ and TOKEN=xyz789\n' > "$TMP/bad.md"
  run scan "polaris_scan_terms '$FM' '$TMP/bad.md'"
  [ "$status" -eq 1 ]
  [[ "$output" != *"SECRETPROJ"* ]]
  [[ "$output" != *"TOKEN=xyz789"* ]]
  [[ "$output" == *"bad.md"* ]]
  [ "$(grep -c 'bad.md:1' <<< "$output")" -eq 1 ]
}

@test "scan: overlapping terms are masked longest-first (no stray fragment)" {
  printf 'see alpha-beta now\n' > "$TMP/ov.md"
  run scan "polaris_scan_terms '$FM' '$TMP/ov.md'"
  [[ "$output" != *"-beta"* ]]
}

@test "scan: a generic term still echoes (public, not redacted)" {
  printf 'here GENPATH appears\n' > "$TMP/g.md"
  run scan "polaris_scan_terms '$FM' '$TMP/g.md'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"GENPATH"* ]]
}

@test "pathnames: a private term in a filename is caught and redacted" {
  run scan "polaris_scan_pathnames '$FM' 'src/SECRETPROJ-notes.md' 'core/ok.md'"
  [ "$status" -eq 1 ]
  [[ "$output" != *"SECRETPROJ"* ]]
}

@test "install: creates the three entrypoints and is idempotent" {
  app="$TMP/app"; mkdir -p "$app"
  run bash "$ROOT/tools/install" --target "$app"
  [ "$status" -eq 0 ]
  [ -f "$app/AGENTS.md" ]
  [ -f "$app/CLAUDE.md" ]
  [ -f "$app/.github/copilot-instructions.md" ]
  cp "$app/AGENTS.md" "$TMP/agents.first"
  run bash "$ROOT/tools/install" --target "$app"
  [[ "$output" == *"already up to date"* ]]
  cmp "$TMP/agents.first" "$app/AGENTS.md"
}

@test "install: preserves surrounding text and collapses duplicate blocks" {
  app="$TMP/app2"; mkdir -p "$app"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  blk="$(cat "$app/AGENTS.md")"
  printf '# top\n%s\n\nMIDDLE\n\n%s\n# bottom\n' "$blk" "$blk" > "$app/AGENTS.md"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  run grep -c '^<!-- AGENT-RULES:BEGIN' "$app/AGENTS.md"
  [ "$output" -eq 1 ]
  run grep -c '^<!-- AGENT-RULES:END' "$app/AGENTS.md"
  [ "$output" -eq 1 ]
  grep -q 'MIDDLE' "$app/AGENTS.md"
  grep -q '# top' "$app/AGENTS.md"
  grep -q '# bottom' "$app/AGENTS.md"
}

@test "install: refuses a BEGIN-without-END block (no silent data loss)" {
  app="$TMP/app3"; mkdir -p "$app"
  printf '<!-- AGENT-RULES:BEGIN x -->\nstale body\n# KEEP ME\n' > "$app/CLAUDE.md"
  before="$(cat "$app/CLAUDE.md")"
  run bash "$ROOT/tools/install" --target "$app"
  [ "$status" -ne 0 ]
  [ "$(cat "$app/CLAUDE.md")" = "$before" ]
}

@test "check: repo scope fails when an adapter is missing" {
  app="$TMP/app4"; mkdir -p "$app"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  rm "$app/CLAUDE.md"
  run bash "$ROOT/tools/install" --target "$app" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"MISSING"* ]]
}

@test "remove: keeps user text, deletes Polaris-only files" {
  app="$TMP/app5"; mkdir -p "$app"
  printf '# Mine\nkeep this\n' > "$app/AGENTS.md"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  run bash "$ROOT/tools/install" --target "$app" --remove
  [ "$status" -eq 0 ]
  grep -q 'keep this' "$app/AGENTS.md"
  ! grep -q 'AGENT-RULES:BEGIN' "$app/AGENTS.md"
  [ ! -f "$app/CLAUDE.md" ]
}

@test "bundle sha is stable across calls (deterministic)" {
  a="$(polaris_bundle_sha256 "$ROOT/core" "$ROOT/MANIFEST.json")"
  b="$(polaris_bundle_sha256 "$ROOT/core" "$ROOT/MANIFEST.json")"
  [ "$a" = "$b" ]
}

@test "bundle sha fails closed when render fails without caller pipefail" {
  bad="$TMP/badbundle"; mkdir -p "$bad/core"
  cat > "$bad/MANIFEST.json" <<'JSON'
{
  "schema_version": 1,
  "name": "polaris",
  "core_dir": "core",
  "required_core_read_order": ["core/MISSING.md"],
  "optional_core_files": ["core/OPTIONAL.md"],
  "forbidden_core_terms": [],
  "render_budget_bytes": 32768
}
JSON
  printf 'optional\n' > "$bad/core/OPTIONAL.md"
  run bash -c 'set +o pipefail; source "$1"; polaris_bundle_sha256 "$2/core" "$2/MANIFEST.json" 2>&1' _ "$ROOT/tools/polaris-lib.sh" "$bad"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing required core file: core/MISSING.md"* ]]
  [[ "$output" != *"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"* ]]
}

@test "check (end-to-end): catches an absolute home path in an UNTRACKED file" {
  repo="$TMP/gitrepo"; mkdir -p "$repo"
  cp -R "$ROOT/tools" "$ROOT/core" "$ROOT/MANIFEST.json" "$repo/"
  ( cd "$repo" && git init -q && git add -A \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm init >/dev/null 2>&1 )
  # Build the home-path leak at runtime so this test FILE never contains the
  # literal home-path prefix (which the repo's own scan would flag).
  home="/Users"
  printf 'leaked path %s/somebody/secret\n' "$home" > "$repo/leak.md"   # untracked
  run bash "$repo/tools/check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"leak.md"* ]]
}

@test "check (end-to-end): a clean untracked tree passes" {
  repo="$TMP/gitclean"; mkdir -p "$repo"
  cp -R "$ROOT/tools" "$ROOT/core" "$ROOT/MANIFEST.json" "$repo/"
  ( cd "$repo" && git init -q && git add -A \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm init >/dev/null 2>&1 )
  printf 'nothing to see here\n' > "$repo/ok.md"
  run bash "$repo/tools/check"
  [ "$status" -eq 0 ]
}

@test "check: reports DRIFT when a managed block body is stale" {
  app="$TMP/appd"; mkdir -p "$app"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  awk '{gsub(/Operating Contract/, "Operating Contract X"); print}' "$app/AGENTS.md" > "$app/AGENTS.md.t"
  mv "$app/AGENTS.md.t" "$app/AGENTS.md"
  run bash "$ROOT/tools/install" --target "$app" --check
  [ "$status" -ne 0 ]
  [[ "$output" == *"DRIFT"* ]]
}

@test "status: reports STALE when a managed block body is tampered" {
  app="$TMP/appstatus"; mkdir -p "$app"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  awk 'done == 0 && /## Modes/ { sub(/## Modes/, "## Modes Tampered"); done = 1 } { print }' \
    "$app/AGENTS.md" > "$app/AGENTS.md.t"
  mv "$app/AGENTS.md.t" "$app/AGENTS.md"
  run bash "$ROOT/tools/status" --target "$app"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STALE"*"AGENTS.md"* ]]
}

@test "install: REVIEW mode is self-contained in generated adapters" {
  app="$TMP/appreview"; mkdir -p "$app"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  grep -q 'severity, exact location' "$app/AGENTS.md"
  ! grep -q 'deep-review protocol' "$app/AGENTS.md"
}

@test "adapter metadata: repo targets match tooling helpers" {
  app="$TMP/appmeta"; mkdir -p "$app"
  awk -F '\t' 'NF && $1 !~ /^#/ { print $4 }' "$ROOT/templates/adapters/tool-metadata.tsv" \
    | sort -u > "$TMP/metadata-repo-targets"
  while IFS= read -r target; do
    printf '%s\n' "${target#"$app"/}"
  done < <(polaris_repo_adapter_targets "$app") | sort -u > "$TMP/helper-repo-targets"

  run diff -u "$TMP/metadata-repo-targets" "$TMP/helper-repo-targets"
  [ "$status" -eq 0 ]
}

@test "adapter metadata: rows are dated and reflected in docs" {
  rows=0
  while IFS=$'\t' read -r slug display binary repo_entrypoint global_entrypoint imports install_scope evidence_status evidence_date evidence_source; do
    rows=$((rows + 1))
    [[ "$repo_entrypoint" != /* ]]
    [[ "$global_entrypoint" != "" ]]
    [[ "$imports" == "yes" || "$imports" == "no" ]]
    [[ "$install_scope" == "repo-only" || "$install_scope" == "repo+global" ]]
    [[ "$evidence_status" == "live-verified" || "$evidence_status" == "docs-confirmed" || "$evidence_status" == "local-package-confirmed" ]]
    [[ "$evidence_date" =~ ^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$ ]]
    [[ -n "$evidence_source" ]]
    grep -Fq "$display" "$ROOT/README.md"
    grep -Fq "$display" "$ROOT/docs/tool-ingestion.md"
    grep -Fq "$repo_entrypoint" "$ROOT/README.md"
    grep -Fq "$repo_entrypoint" "$ROOT/docs/tool-ingestion.md"
    grep -Fq "$evidence_status $evidence_date" "$ROOT/docs/tool-ingestion.md"
  done < <(awk -F '\t' 'NF && $1 !~ /^#/ { print }' "$ROOT/templates/adapters/tool-metadata.tsv")
  [ "$rows" -eq 5 ]
}

@test "status: labels and CLI binary list come from adapter metadata" {
  app="$TMP/appstatusmeta"; mkdir -p "$app"
  bash "$ROOT/tools/install" --target "$app" >/dev/null
  run bash "$ROOT/tools/status" --target "$app"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AGENTS.md"*"Codex, opencode, Pi CLI"* ]]
  [[ "$output" == *"CLAUDE.md"*"Claude Code"* ]]
  [[ "$output" == *"copilot-instructions.md"*"GitHub Copilot"* ]]
  [[ "$output" == *"claude="* ]]
  [[ "$output" == *"codex="* ]]
  [[ "$output" == *"opencode="* ]]
  [[ "$output" == *"pi="* ]]
}

@test "status: reports Codex global AGENTS.md as overridden when AGENTS.override.md exists" {
  g="$TMP/home-override"; mkdir -p "$g/.codex"
  env HOME="$g" CODEX_HOME="$g/.codex" XDG_CONFIG_HOME="$g/.config" \
      PI_CODING_AGENT_DIR="$g/.pi/agent" bash "$ROOT/tools/install" --global >/dev/null
  printf '# override\n' > "$g/.codex/AGENTS.override.md"

  run env HOME="$g" CODEX_HOME="$g/.codex" XDG_CONFIG_HOME="$g/.config" \
      PI_CODING_AGENT_DIR="$g/.pi/agent" bash "$ROOT/tools/status"
  [ "$status" -eq 0 ]
  [[ "$output" == *"overridden"*"~/.codex/AGENTS.md"*"AGENTS.override.md takes precedence"* ]]
}

@test "manifest paths: missing optional core file fails the core check" {
  vendor="$TMP/vendor-missing-optional"; mkdir -p "$vendor"
  cp -R "$ROOT/core" "$ROOT/MANIFEST.json" "$vendor/"
  rm "$vendor/core/ADAPTERS.md"
  run scan "polaris_check_core '$vendor/core' '$vendor/MANIFEST.json'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing optional core file: core/ADAPTERS.md"* ]]
}

@test "manifest paths: core_dir argument must match the manifest" {
  vendor="$TMP/vendor-core-arg"; mkdir -p "$vendor"
  cp -R "$ROOT/core" "$ROOT/MANIFEST.json" "$vendor/"
  mkdir -p "$vendor/not-core"
  run scan "polaris_check_core '$vendor/not-core' '$vendor/MANIFEST.json'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"core_dir argument does not match manifest core_dir 'core'"* ]]
}

@test "manifest paths: required core files cannot escape core_dir" {
  vendor="$TMP/vendor-escape"; mkdir -p "$vendor/core"
  cat > "$vendor/MANIFEST.json" <<'JSON'
{
  "schema_version": 1,
  "name": "polaris",
  "core_dir": "core",
  "required_core_read_order": ["../outside.md"],
  "optional_core_files": [],
  "forbidden_core_terms": [],
  "render_budget_bytes": 32768
}
JSON
  run scan "polaris_check_manifest_paths '$vendor/MANIFEST.json'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsafe path segment"* ]]
}

@test "scan: a private hit reports a line number (location, not just file)" {
  printf 'a\nb SECRETPROJ here\n' > "$TMP/loc.md"
  run scan "polaris_scan_terms '$FM' '$TMP/loc.md'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"loc.md:2"* ]]
}

@test "scan: a pure-word term does not trip a longer word containing it" {
  printf 'the GENPATHological edge case\n' > "$TMP/wb.md"
  run scan "polaris_scan_terms '$FM' '$TMP/wb.md'"
  [ "$status" -eq 0 ]
}

@test "remove: refuses a BEGIN-without-END block (no data loss)" {
  app="$TMP/appr"; mkdir -p "$app"
  printf '<!-- AGENT-RULES:BEGIN x -->\nstale\n# KEEP ME\n' > "$app/AGENTS.md"
  before="$(cat "$app/AGENTS.md")"
  run bash "$ROOT/tools/install" --target "$app" --remove
  [ "$status" -ne 0 ]
  [ "$(cat "$app/AGENTS.md")" = "$before" ]
}

@test "install --global: writes the four per-user entrypoints (env-overridden)" {
  g="$TMP/home"; mkdir -p "$g"
  run env HOME="$g" CODEX_HOME="$g/.codex" XDG_CONFIG_HOME="$g/.config" \
      PI_CODING_AGENT_DIR="$g/.pi/agent" bash "$ROOT/tools/install" --global
  [ "$status" -eq 0 ]
  [ -f "$g/.codex/AGENTS.md" ]
  [ -f "$g/.claude/CLAUDE.md" ]
  [ -f "$g/.config/opencode/AGENTS.md" ]
  [ -f "$g/.pi/agent/AGENTS.md" ]
  grep -q '^<!-- AGENT-RULES:BEGIN' "$g/.claude/CLAUDE.md"
}

@test "install --global: warns when Codex AGENTS.override.md shadows AGENTS.md" {
  g="$TMP/home-global-override"; mkdir -p "$g/.codex"
  printf '# override\n' > "$g/.codex/AGENTS.override.md"
  run env HOME="$g" CODEX_HOME="$g/.codex" XDG_CONFIG_HOME="$g/.config" \
      PI_CODING_AGENT_DIR="$g/.pi/agent" bash "$ROOT/tools/install" --global
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: Codex will load"*"AGENTS.override.md"* ]]
  [[ "$output" == *"may be shadowed for Codex"* ]]
}

@test "verify-vendor: expected hash is required unless structure-only is explicit" {
  vendor="$TMP/vendor-verify"; mkdir -p "$vendor"
  cp -R "$ROOT/core" "$ROOT/MANIFEST.json" "$vendor/"
  expected="$(polaris_bundle_sha256 "$vendor/core" "$vendor/MANIFEST.json")"

  run bash "$ROOT/tools/verify-vendor" "$vendor"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage: tools/verify-vendor <vendor-dir> <expected-bundle-sha256>"* ]]

  run bash "$ROOT/tools/verify-vendor" --structure-only "$vendor"
  [ "$status" -eq 0 ]
  [[ "$output" == *"STRUCTURE ONLY"* ]]

  run bash "$ROOT/tools/verify-vendor" "$vendor" "$expected"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bundle MATCHES"* ]]
}

@test "release-check: fails when changelog lacks current bundle sha" {
  make_release_fixture
  sed 's/bundle-sha256:.*/bundle-sha256:** `0000000000000000000000000000000000000000000000000000000000000000`/' "$rel/CHANGELOG.md" > "$rel/CHANGELOG.md.t"
  mv "$rel/CHANGELOG.md.t" "$rel/CHANGELOG.md"
  ( cd "$rel" && git add CHANGELOG.md && git -c user.email=ci@polaris.test -c user.name=ci commit -qm bad-hash )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHANGELOG.md bundle-sha256 mismatch"* ]]
}

@test "release-check: requires an exact changelog version heading" {
  make_release_fixture
  printf '1.2.3\n' > "$rel/VERSION"
  cat > "$rel/CHANGELOG.md" <<EOF
# Changelog

## [11.2.3] - 2099-01-01

**bundle-sha256:** \`$rel_sha\`
EOF
  ( cd "$rel" && git add CHANGELOG.md VERSION \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm wrong-section )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHANGELOG.md has no section for version 1.2.3"* ]]
}

@test "release-check: rejects non-semver VERSION values" {
  make_release_fixture
  printf 'Unreleased\n' > "$rel/VERSION"
  cat > "$rel/CHANGELOG.md" <<EOF
# Changelog

## [Unreleased]

**bundle-sha256:** \`$rel_sha\`
EOF
  ( cd "$rel" && git add CHANGELOG.md VERSION \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm bad-version )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"VERSION must be SemVer x.y.z"* ]]
}

@test "release-check: ignores fenced changelog headings" {
  make_release_fixture
  printf '1.2.3\n' > "$rel/VERSION"
  cat > "$rel/CHANGELOG.md" <<EOF
# Changelog

\`\`\`md
## [1.2.3] - 2099-01-01

**bundle-sha256:** \`$rel_sha\`
\`\`\`
EOF
  ( cd "$rel" && git add CHANGELOG.md VERSION \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm fenced-heading )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHANGELOG.md has no section for version 1.2.3"* ]]
}

@test "release-check: rejects duplicate changelog version sections" {
  make_release_fixture
  cat >> "$rel/CHANGELOG.md" <<EOF

## [0.1.0] - 2099-01-02

**bundle-sha256:** \`$rel_sha\`
EOF
  ( cd "$rel" && git add CHANGELOG.md \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm duplicate-section )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHANGELOG.md has multiple sections for version 0.1.0"* ]]
}

@test "release-check: rejects duplicate bundle hashes in the release section" {
  make_release_fixture
  cat >> "$rel/CHANGELOG.md" <<EOF
**bundle-sha256:** \`0000000000000000000000000000000000000000000000000000000000000000\`
EOF
  ( cd "$rel" && git add CHANGELOG.md \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm duplicate-hash )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHANGELOG.md section for 0.1.0 has multiple bundle-sha256 entries"* ]]
}

@test "release-check: refuses a dirty working tree" {
  make_release_fixture
  printf 'dirty\n' >> "$rel/CHANGELOG.md"
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unstaged changes"* ]]
}

@test "release-check: refuses staged changes" {
  make_release_fixture
  printf 'staged\n' >> "$rel/CHANGELOG.md"
  ( cd "$rel" && git add CHANGELOG.md )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"index has staged changes"* ]]
}

@test "release-check: refuses untracked files" {
  make_release_fixture
  printf 'untracked\n' > "$rel/scratch.txt"
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"untracked files present"* ]]
}

@test "release-check: prints the certified commit on success" {
  make_release_fixture
  commit="$(cd "$rel" && git rev-parse --verify HEAD)"
  run bash "$rel/tools/release-check"
  [ "$status" -eq 0 ]
  [[ "$output" == *"certified commit $commit"* ]]
  run cat "$rel/release-gates.log"
  [ "$status" -eq 0 ]
  [ "$output" = $'install --check\nci\ntests' ]
}

@test "release-check: propagates adapter drift gate failure" {
  make_release_fixture
  printf '#!/usr/bin/env bash\nprintf "install %%s\\n" "$*" >> release-gates.log\necho install failed >&2\nexit 42\n' > "$rel/tools/install"
  chmod +x "$rel/tools/install"
  commit_release_fixture_change
  run bash "$rel/tools/release-check"
  [ "$status" -eq 42 ]
  [[ "$output" == *"install failed"* ]]
}

@test "release-check: propagates ci gate failure" {
  make_release_fixture
  printf '#!/usr/bin/env bash\nprintf "ci\\n" >> release-gates.log\necho ci failed >&2\nexit 43\n' > "$rel/tools/ci"
  chmod +x "$rel/tools/ci"
  commit_release_fixture_change
  run bash "$rel/tools/release-check"
  [ "$status" -eq 43 ]
  [[ "$output" == *"ci failed"* ]]
}

@test "release-check: propagates bats gate failure" {
  make_release_fixture
  printf '#!/usr/bin/env bash\nprintf "tests\\n" >> release-gates.log\necho tests failed >&2\nexit 44\n' > "$rel/tests/run.sh"
  chmod +x "$rel/tests/run.sh"
  commit_release_fixture_change
  run bash "$rel/tools/release-check"
  [ "$status" -eq 44 ]
  [[ "$output" == *"tests failed"* ]]
}

@test "release-check: refuses an existing local version tag" {
  make_release_fixture
  ( cd "$rel" && git tag "v$(tr -d ' \r\n' < VERSION)" )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"local tag v"*"already exists"* ]]
}

@test "release-check: refuses an existing checkable remote version tag" {
  make_release_fixture
  remote="$TMP/origin.git"
  seed="$TMP/remote-seed"
  git init --bare -q "$remote"
  mkdir -p "$seed"
  ( cd "$seed" && git init -q && printf 'seed\n' > README.md && git add README.md \
      && git -c user.email=ci@polaris.test -c user.name=ci commit -qm seed \
      && git tag "v$(tr -d ' \r\n' < "$rel/VERSION")" \
      && git remote add origin "$remote" && git push -q origin --tags )
  ( cd "$rel" && git remote add origin "$remote" )
  run bash "$rel/tools/release-check"
  [ "$status" -ne 0 ]
  [[ "$output" == *"remote tag v"*"already exists on origin"* ]]
}

@test "ruleset-check: validates local semantics and rejects wrong ci context" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  rules="$TMP/rulesets"; mkdir -p "$rules"
  cp "$ROOT/.github/rulesets/"*.json "$rules/"
  run bash "$ROOT/tools/ruleset-check" --ruleset-dir "$rules"
  [ "$status" -eq 0 ]
  jq '(.rules[] | select(.type == "required_status_checks").parameters.required_status_checks[0].context) = "not-ci"' \
    "$rules/main-integrity.json" > "$rules/main-integrity.json.t"
  mv "$rules/main-integrity.json.t" "$rules/main-integrity.json"
  run bash "$ROOT/tools/ruleset-check" --ruleset-dir "$rules"
  [ "$status" -ne 0 ]
  [[ "$output" == *"required status checks require only GitHub Actions ci"* ]]

  jq 'del(.rules[] | select(.type == "required_status_checks").parameters.required_status_checks[0].integration_id)' \
    "$rules/main-integrity.json" > "$rules/main-integrity.json.t"
  mv "$rules/main-integrity.json.t" "$rules/main-integrity.json"
  run bash "$ROOT/tools/ruleset-check" --ruleset-dir "$rules"
  [ "$status" -ne 0 ]
  [[ "$output" == *"required status checks require only GitHub Actions ci"* ]]
}

@test "ruleset-check: rejects duplicate or unknown rule types" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  rules="$TMP/rulesets-duplicate"; mkdir -p "$rules"
  cp "$ROOT/.github/rulesets/"*.json "$rules/"
  jq '.rules += [{"type": "deletion"}]' "$rules/main-integrity.json" > "$rules/main-integrity.json.t"
  mv "$rules/main-integrity.json.t" "$rules/main-integrity.json"
  run bash "$ROOT/tools/ruleset-check" --ruleset-dir "$rules"
  [ "$status" -ne 0 ]
  [[ "$output" == *"has exactly the expected rule types"* ]]
}

@test "ruleset-check: verifies exact owner bypass id when supplied" {
  if ! command -v jq >/dev/null 2>&1; then
    skip "jq not installed"
  fi
  rules="$TMP/rulesets-owner"; mkdir -p "$rules"
  cp "$ROOT/.github/rulesets/"*.json "$rules/"
  owner="$(jq -r '.bypass_actors[0].actor_id' "$rules/main-integrity.json")"
  wrong=1
  [ "$owner" = 1 ] && wrong=2

  run bash "$ROOT/tools/ruleset-check" --ruleset-dir "$rules" --owner-id "$owner"
  [ "$status" -eq 0 ]

  run bash "$ROOT/tools/ruleset-check" --ruleset-dir "$rules" --owner-id "$wrong"
  [ "$status" -ne 0 ]
  [[ "$output" == *"bypass actor id matches repository owner"* ]]
}

@test "install.ps1 write preserves surrounding text and cleans temp files" {
  if ! command -v pwsh >/dev/null 2>&1; then
    if [ "${POLARIS_STRICT:-0}" = 1 ]; then
      echo "pwsh is REQUIRED in strict mode (amd64 Windows-parity coverage); not installed."
      return 1
    fi
    skip "pwsh not installed (set POLARIS_STRICT=1 to require it)"
  fi
  app="$TMP/ps-atomic"; mkdir -p "$app"
  printf '# Mine\nkeep this\n' > "$app/AGENTS.md"

  run pwsh -NoProfile -File "$ROOT/tools/install.ps1" -Target "$app"
  [ "$status" -eq 0 ]
  grep -q 'keep this' "$app/AGENTS.md"
  run find "$app" -name '.polaris.*' -print
  [ "$output" = "" ]
}

@test "install.ps1 refuses malformed blocks without changing the file" {
  if ! command -v pwsh >/dev/null 2>&1; then
    if [ "${POLARIS_STRICT:-0}" = 1 ]; then
      echo "pwsh is REQUIRED in strict mode (amd64 Windows-parity coverage); not installed."
      return 1
    fi
    skip "pwsh not installed (set POLARIS_STRICT=1 to require it)"
  fi
  app="$TMP/ps-malformed"; mkdir -p "$app"
  printf '<!-- AGENT-RULES:BEGIN x -->\nstale body\n# KEEP ME\n' > "$app/CLAUDE.md"
  before="$(cat "$app/CLAUDE.md")"

  run pwsh -NoProfile -File "$ROOT/tools/install.ps1" -Target "$app"
  [ "$status" -ne 0 ]
  [ "$(cat "$app/CLAUDE.md")" = "$before" ]
  run find "$app" -name '.polaris.*' -print
  [ "$output" = "" ]
}

# pwsh is REQUIRED in strict mode (CI runs strict): the bash-vs-pwsh byte-identity
# parity is the only thing that proves the Windows installer is correct, and it
# runs on the amd64 ubuntu runner -- the same architecture Windows actually ships
# on. A coincidentally-missing pwsh must FAIL loudly here, never silently skip.
@test "install.ps1 renders byte-identical to the bash installer (amd64 parity)" {
  if ! command -v pwsh >/dev/null 2>&1; then
    if [ "${POLARIS_STRICT:-0}" = 1 ]; then
      echo "pwsh is REQUIRED in strict mode (amd64 Windows-parity coverage); not installed."
      return 1
    fi
    skip "pwsh not installed (set POLARIS_STRICT=1 to require it)"
  fi
  a="$TMP/psa"; b="$TMP/psb"; mkdir -p "$a" "$b"
  bash "$ROOT/tools/install" --target "$a" >/dev/null
  pwsh -NoProfile -File "$ROOT/tools/install.ps1" -Target "$b" >/dev/null
  for f in AGENTS.md CLAUDE.md .github/copilot-instructions.md; do
    cmp -s "$a/$f" "$b/$f" || { echo "byte mismatch: $f"; return 1; }
  done
}

@test "install.ps1 --check agrees the committed entrypoints are drift-free (amd64 parity)" {
  if ! command -v pwsh >/dev/null 2>&1; then
    if [ "${POLARIS_STRICT:-0}" = 1 ]; then
      echo "pwsh is REQUIRED in strict mode (amd64 Windows-parity coverage); not installed."
      return 1
    fi
    skip "pwsh not installed (set POLARIS_STRICT=1 to require it)"
  fi
  run pwsh -NoProfile -File "$ROOT/tools/install.ps1" -Check
  [ "$status" -eq 0 ]
  [[ "$output" == *"blocks up to date"* ]]
}
