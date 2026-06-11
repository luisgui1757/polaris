#!/usr/bin/env bash
# Run the Polaris bats suite. Skips (non-fatally) if bats is not installed, so a
# clean clone without bats can still `make ci`; CI installs bats and enforces it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v bats >/dev/null 2>&1; then
  echo "tests: bats-core not installed; skipping. Install it to run the suite." >&2
  exit 0
fi

exec bats "$ROOT/tests"
