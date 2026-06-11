#!/usr/bin/env bash
# Polaris generic library.
#
# This file is the GENERIC half of Polaris tooling. It operates only on a
# Polaris core directory plus its MANIFEST.json and knows nothing about any
# consuming repository's overlay paths. Consumers `source` this file and add
# their own overlay-aware checks on top, so the generic checks are never
# copy-pasted into each consumer.
#
# Usage:
#   source "<vendor>/tools/polaris-lib.sh"
#   polaris_check_core    "<core_dir>" "<manifest.json>"   # returns 0/1
#   polaris_render_core   "<core_dir>" "<manifest.json>"   # human-readable dump
#   polaris_render_bundle "<core_dir>" "<manifest.json>"   # inlinable contract
#   polaris_core_files    "<manifest.json>" [required|all] # prints rel paths
#   polaris_forbidden_terms "<manifest.json>"              # tagged term list
#   polaris_scan_terms    "<manifest.json>" <path...>      # leak scan (0/1)
#
# The functions are pure shell + a JSON reader; no jq dependency.

# Whether jq is available for correct, spec-compliant JSON parsing.
_polaris_have_jq() { command -v jq >/dev/null 2>&1; }

# Read a top-level string scalar from a JSON file.
# Prefers jq (decodes JSON escapes, so a doubly-escaped Windows path becomes the
# real one); falls back to a pure-sed reader so the library has no hard dependency.
# polaris_manifest_value <file> <key>
polaris_manifest_value() {
  local file=$1 key=$2
  [[ -f "$file" ]] || return 1
  if _polaris_have_jq; then
    jq -r --arg k "$key" 'if (has($k) and ((.[$k]|type) == "string")) then .[$k] else empty end' "$file" 2>/dev/null | head -n1
    return
  fi
  sed -n "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$file" | head -n1
}

# Read a top-level integer scalar from a JSON file.
# polaris_manifest_int <file> <key>
polaris_manifest_int() {
  local file=$1 key=$2
  [[ -f "$file" ]] || return 1
  if _polaris_have_jq; then
    jq -r --arg k "$key" 'if (has($k) and ((.[$k]|type) == "number")) then .[$k] else empty end' "$file" 2>/dev/null | head -n1
    return
  fi
  sed -n "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p" "$file" | head -n1
}

# Print the entries of a top-level JSON string array, one per line. With jq the
# values are correctly JSON-decoded (escapes resolved, a "]" inside a string is
# safe); the pure-awk fallback handles the common case with no dependency.
# polaris_manifest_array <file> <key>
polaris_manifest_array() {
  local file=$1 key=$2
  [[ -f "$file" ]] || return 1
  if _polaris_have_jq; then
    jq -r --arg k "$key" '(.[$k] // []) | if type == "array" then .[] else empty end' "$file" 2>/dev/null
    return
  fi
  awk -v key="\"$key\"" '
    BEGIN { inarr = 0 }
    {
      if (inarr) {
        line = $0
        if (line ~ /\]/) { inarr = 0 }
        while (match(line, /"[^"]*"/)) {
          item = substr(line, RSTART + 1, RLENGTH - 2)
          print item
          line = substr(line, RSTART + RLENGTH)
        }
        next
      }
      if (index($0, key) > 0 && index($0, "[") > 0) {
        inarr = 1
        rest = substr($0, index($0, "[") + 1)
        if (rest ~ /\]/) { inarr = 0 }
        while (match(rest, /"[^"]*"/)) {
          item = substr(rest, RSTART + 1, RLENGTH - 2)
          print item
          rest = substr(rest, RSTART + RLENGTH)
        }
      }
    }
  ' "$file" | sed 's/\\\\/\\/g; s/\\"/"/g'   # best-effort JSON unescape to match jq
}

# List core files relative to the manifest's core layout.
# polaris_core_files <manifest> [required|all]   (default: all)
polaris_core_files() {
  local manifest=$1 scope=${2:-all}
  polaris_manifest_array "$manifest" required_core_read_order
  if [[ "$scope" == "all" ]]; then
    polaris_manifest_array "$manifest" optional_core_files
  fi
}

# Print the merged forbidden-term list, one TAB-tagged entry per line:
#   "M<TAB>term"  - generic, publishable term from the manifest
#   "L<TAB>term"  - private term from the gitignored local denylist
#
# The PUBLIC manifest holds only generic patterns (absolute home paths, etc.)
# that are safe to publish. Project-specific / domain / stack terms live ONLY
# in the gitignored file named by the manifest "local_denylist" value, so the
# committed tree never enumerates the owner's other projects. The local file is
# resolved relative to the manifest directory and is absent in the public tree.
# polaris_forbidden_terms <manifest> [all|M|L]   (default: all)
polaris_forbidden_terms() {
  local manifest=$1 filter=${2:-all} base term local_denylist
  base=$(cd "$(dirname "$manifest")" && pwd)
  if [[ "$filter" == all || "$filter" == M ]]; then
    while IFS= read -r term; do
      [[ -n "$term" ]] && printf 'M\t%s\n' "$term"
    done < <(polaris_manifest_array "$manifest" forbidden_core_terms)
  fi
  if [[ "$filter" == all || "$filter" == L ]]; then
    local_denylist=$(polaris_manifest_value "$manifest" local_denylist)
    # Default location if the manifest names none, so the private scan still
    # works when the manifest key is absent (or has been reverted).
    [[ -z "$local_denylist" ]] && local_denylist="tools/forbidden-terms.local"
    if [[ -f "$base/$local_denylist" ]]; then
      # One term per line; strip "#" comments, blank lines, and surrounding space.
      sed -e 's/[[:space:]]*#.*$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
          -e '/^$/d' "$base/$local_denylist" \
        | while IFS= read -r term; do
            [[ -n "$term" ]] && printf 'L\t%s\n' "$term"
          done
    fi
  fi
}

# Scan one or more paths for forbidden terms. Returns 0 if clean, 1 on any hit.
# Privacy guarantees:
#   - A private (L) hit reports the LOCATION ONLY (path:line) -- never the
#     matched content -- so neither the private term nor any adjacent unrelated
#     secret on that line can leak. Any private term in the path itself is masked.
#   - A generic (M) hit shows its line (M-terms are public), but every private
#     term on that line is masked first.
#   - Masking is applied longest-term-first, so a shorter term cannot split a
#     longer overlapping one ("alpha-beta" is masked whole, not "<X>-beta").
#   - -H forces a filename prefix even for a single path; -a treats binaries as
#     text so a term in a binary asset cannot evade the scan; a grep error
#     (unreadable path, rc>=2) fails closed rather than reading as "clean".
# Pass --private to scan for L-terms only (e.g. a file that legitimately declares
# the generic terms, like the manifest).
# polaris_scan_terms <manifest> [--private] <path...>
polaris_scan_terms() {
  local manifest=$1; shift
  local filter=all
  if [[ "${1:-}" == "--private" ]]; then filter=L; shift; fi
  [[ $# -gt 0 ]] || return 0

  # Collect every private term, then sort longest-first for safe masking.
  local lterms=() o t
  while IFS=$'\t' read -r o t; do
    [[ "$o" == L && -n "$t" ]] && lterms+=("$t")
  done < <(polaris_forbidden_terms "$manifest" L)
  if ((${#lterms[@]} > 1)); then
    local _sorted; _sorted=$(printf '%s\n' "${lterms[@]}" | awk '{print length"\t"$0}' | sort -rn | cut -f2-)
    lterms=(); while IFS= read -r t; do [[ -n "$t" ]] && lterms+=("$t"); done <<< "$_sorted"
  fi

  # Mask every private term (longest-first) out of a string.
  _polaris_mask() {
    local s=$1 lt
    if ((${#lterms[@]})); then for lt in "${lterms[@]}"; do s=${s//"$lt"/<REDACTED>}; done; fi
    printf '%s' "$s"
  }

  local origin term grep_out rc failed=0 idx=0 wordflag line
  while IFS=$'\t' read -r origin term; do
    [[ -n "$term" ]] || continue
    if [[ "$term" =~ ^[A-Za-z0-9_]+$ ]]; then wordflag="-w"; else wordflag=""; fi
    grep_out=$(grep -R -n -H -a -F $wordflag -- "$term" "$@" 2>/dev/null); rc=$?
    if [[ -n "$grep_out" ]]; then
      failed=1
      if [[ "$origin" == L ]]; then
        idx=$((idx + 1))
        echo "polaris: private denylist term #$idx found (redacted, location only):" >&2
        # path:line only -- strip the matched content; mask any private term in the path.
        while IFS= read -r line; do
          printf '   %s\n' "$(_polaris_mask "$line")" >&2
        done < <(printf '%s\n' "$grep_out" | sed 's/:\([0-9][0-9]*\):.*/:\1/')
      else
        echo "polaris: forbidden term '$(_polaris_mask "$term")':" >&2
        while IFS= read -r line; do
          printf '   %s\n' "$(_polaris_mask "$line")" >&2
        done <<< "$grep_out"
      fi
    fi
    if [[ $rc -ge 2 ]]; then
      echo "polaris: WARNING: a path could not be fully scanned (grep rc=$rc); failing closed." >&2
      failed=1
    fi
  done < <(polaris_forbidden_terms "$manifest" "$filter")
  return $failed
}

# Scan a list of repo-relative path STRINGS for forbidden terms in the names
# themselves (a file/dir named after a private project still leaks even if its
# content is clean). Reports the masked path -- a path name minus the term is not
# itself a secret. Pass repo-relative paths so absolute prefixes (e.g. a home
# path) do not false-positive. Returns 1 on any hit.
# polaris_scan_pathnames <manifest> <relpath...>
polaris_scan_pathnames() {
  local manifest=$1; shift
  [[ $# -gt 0 ]] || return 0
  local paths=("$@")

  local lterms=() o t
  while IFS=$'\t' read -r o t; do
    [[ "$o" == L && -n "$t" ]] && lterms+=("$t")
  done < <(polaris_forbidden_terms "$manifest" L)
  if ((${#lterms[@]} > 1)); then
    local _s; _s=$(printf '%s\n' "${lterms[@]}" | awk '{print length"\t"$0}' | sort -rn | cut -f2-)
    lterms=(); while IFS= read -r t; do [[ -n "$t" ]] && lterms+=("$t"); done <<< "$_s"
  fi
  _polaris_mask_path() {
    local s=$1 lt
    if ((${#lterms[@]})); then for lt in "${lterms[@]}"; do s=${s//"$lt"/<REDACTED>}; done; fi
    printf '%s' "$s"
  }

  local origin term failed=0 p wordful
  while IFS=$'\t' read -r origin term; do
    [[ -n "$term" ]] || continue
    [[ "$term" =~ ^[A-Za-z0-9_]+$ ]] && wordful=1 || wordful=0
    for p in "${paths[@]}"; do
      [[ -n "$p" ]] || continue
      if [[ "$wordful" == 1 ]]; then
        [[ "$p" =~ (^|[^A-Za-z0-9_])"$term"([^A-Za-z0-9_]|$) ]] || continue
      else
        [[ "$p" == *"$term"* ]] || continue
      fi
      failed=1
      echo "polaris: forbidden term in a tracked path name: $(_polaris_mask_path "$p")" >&2
    done
  done < <(polaris_forbidden_terms "$manifest")
  return $failed
}

# Verify the Polaris core against its manifest.
# polaris_check_core <core_dir> <manifest>
# Emits diagnostics to stderr; returns 0 on success, 1 on any failure.
polaris_check_core() {
  local core_dir=$1 manifest=$2
  local base failed=0
  base=$(cd "$(dirname "$manifest")" && pwd)

  if [[ ! -f "$manifest" ]]; then
    echo "polaris: missing manifest: $manifest" >&2
    return 1
  fi

  local name
  name=$(polaris_manifest_value "$manifest" name)
  if [[ "$name" != "polaris" ]]; then
    echo "polaris: manifest must name the core 'polaris' (got '${name:-<none>}')" >&2
    failed=1
  fi

  local rel
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    if [[ ! -f "$base/$rel" ]]; then
      echo "polaris: missing required core file: $rel" >&2
      failed=1
    fi
  done < <(polaris_manifest_array "$manifest" required_core_read_order)

  # Forbidden-term scan over the core directory (generic + local denylist).
  polaris_scan_terms "$manifest" "$core_dir" || failed=1

  return $failed
}

# Print the core read-order files with section banners (human-readable dump).
# Includes the manifest. Used by `tools/render` for inspection.
# polaris_render_core <core_dir> <manifest>
polaris_render_core() {
  local core_dir=$1 manifest=$2
  local base rel
  base=$(cd "$(dirname "$manifest")" && pwd)
  printf '\n\n===== %s =====\n\n' "$(basename "$manifest")"
  cat "$manifest"
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    [[ -f "$base/$rel" ]] || { echo "polaris: missing core file: $rel" >&2; return 1; }
    printf '\n\n===== %s =====\n\n' "$rel"
    cat "$base/$rel"
  done < <(polaris_core_files "$manifest" required)
}

# Print an inlinable, BRAND-NEUTRAL contract: just the required core rule files,
# concatenated, with every heading demoted one level so each file's title nests
# as a section under the injected document's single title. No manifest dump, no
# banners, and no source-path comments (those would leak the repo's layout), so
# the result embeds directly into a tool's auto-loaded entrypoint.
# polaris_render_bundle <core_dir> <manifest>
polaris_render_bundle() {
  local core_dir=$1 manifest=$2
  local base rel emitted=0
  base=$(cd "$(dirname "$manifest")" && pwd)
  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    [[ -f "$base/$rel" ]] || { echo "polaris: missing core file: $rel" >&2; return 1; }
    awk '
      /^```/ { fence = !fence }
      { if (!fence && $0 ~ /^#{1,6} /) print "#" $0; else print $0 }
    ' "$base/$rel"
    printf '\n'
    emitted=1
  done < <(polaris_core_files "$manifest" required)
  # Refuse to emit an empty bundle: a malformed/unreadable manifest must FAIL
  # loudly, not silently render to nothing (which would hash to the empty-string
  # sha and make a jq machine disagree with a no-jq one).
  if (( emitted == 0 )); then
    echo "polaris: empty required_core_read_order (manifest unreadable or empty); refusing empty bundle" >&2
    return 1
  fi
}

# Canonical sha256 of the rendered bundle -- the single source of truth for the
# version stamp in generated blocks and for drift/status comparisons. Hashes the
# exact bytes polaris_render_bundle emits. Use this EVERYWHERE the bundle sha is
# computed so install, status, and verify-vendor always agree.
# polaris_bundle_sha256 <core_dir> <manifest>
polaris_bundle_sha256() {
  polaris_render_bundle "$1" "$2" | polaris_sha256_stdin
}

# Recompute sha256 sums for the core files and print "<sum>  <relpath>".
# polaris_core_sha256 <core_dir>
polaris_core_sha256() {
  local core_dir=$1 f rel
  local hasher=""
  if command -v sha256sum >/dev/null 2>&1; then
    hasher="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then
    hasher="shasum -a 256"
  else
    echo "polaris: no sha256 tool (sha256sum or shasum) available" >&2
    return 1
  fi
  while IFS= read -r f; do
    rel=${f#"$core_dir"/}
    $hasher "$f" | awk -v r="$rel" '{print $1 "  " r}'
  done < <(find "$core_dir" -type f | sort)
}

# Hash arbitrary content read from stdin; prints the bare sha256 hex digest.
# polaris_sha256_stdin
polaris_sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    echo "polaris: no sha256 tool (sha256sum or shasum) available" >&2
    return 1
  fi
}
