#!/usr/bin/env bash
# Run the Polaris bats suite. In strict mode (POLARIS_STRICT=1, used by CI and
# release-check) a missing bats FAILS -- a gate must never certify having run no
# tests. On a clean dev clone without bats it skips loudly instead of blocking.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  if [[ "${POLARIS_STRICT:-0}" == 1 ]]; then
    echo "tests: FAIL: bats-core is required in strict mode but is not installed." >&2
    exit 1
  fi
  echo "tests: bats-core not installed; SKIPPING (set POLARIS_STRICT=1 to require the suite)." >&2
  exit 0
fi

exec bats "$ROOT/tests"
