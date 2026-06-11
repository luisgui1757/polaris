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

@test "check (end-to-end): catches an absolute home path in an UNTRACKED file" {
  repo="$TMP/gitrepo"; mkdir -p "$repo"
  cp -R "$ROOT/tools" "$ROOT/core" "$ROOT/MANIFEST.json" "$repo/"
  ( cd "$repo" && git init -q && git add -A && git commit -qm init >/dev/null 2>&1 )
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
  ( cd "$repo" && git init -q && git add -A && git commit -qm init >/dev/null 2>&1 )
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
