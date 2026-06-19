#!/usr/bin/env bash
# Applies the repository safeguard posture (branch protection + merge policy).
# Mirrors the house standard; the only required CI check here is `ci`.
set -euo pipefail

usage() {
    cat <<'EOF'
apply-repo-safeguards.sh [owner/repo]

Applies the repository safeguard posture:
  - squash-only PR merges
  - delete branches on merge
  - auto-merge disabled
  - three active main-branch rulesets:
      * Protect main: integrity (required PR, strict CI, no delete/force)
      * Protect main: review (mandatory code-owner review)
      * Protect main: owner updates (only owner can update main)
    The owner is the sole bypass actor on all three, in "always" mode: the
    owner may push directly to main (no PR) and override CI/review; everyone
    else is fully gated (PR + code-owner review + strict `ci`).
  - classic main branch protection fallback with the required `ci` check
  - best-effort GitHub security extras where the plan supports them

Requires an authenticated GitHub CLI with repository admin permission:
  gh auth login
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "FAIL: gh is required. Install GitHub CLI and run gh auth login." >&2
    exit 1
fi

gh auth status >/dev/null

repo="${1:-${GITHUB_REPOSITORY:-}}"
if [[ -z "$repo" ]]; then
    repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi
if [[ "$repo" != */* ]]; then
    echo "FAIL: repository must be owner/repo, got: $repo" >&2
    exit 2
fi

# Re-point ruleset bypass actors to THIS repo's owner so a fork or consumer
# applies its own owner id, not the original author's. Fail CLOSED: this script
# mutates branch protection, so abort before any change unless jq is present and
# the owner id resolved (otherwise a stale/hardcoded actor could be applied).
if ! command -v jq >/dev/null 2>&1; then
    echo "FAIL: jq is required to apply rulesets safely." >&2
    exit 1
fi
OWNER_ID="$(gh api "repos/$repo" --jq '.owner.id' 2>/dev/null || true)"
if [[ -z "$OWNER_ID" ]]; then
    echo "FAIL: could not resolve the repository owner id." >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
integrity_ruleset="$repo_root/.github/rulesets/main-integrity.json"
review_ruleset="$repo_root/.github/rulesets/main-review.json"
owner_updates_ruleset="$repo_root/.github/rulesets/main-owner-updates.json"

for f in "$integrity_ruleset" "$review_ruleset" "$owner_updates_ruleset"; do
    if [[ ! -f "$f" ]]; then
        echo "FAIL: missing ruleset file: $f" >&2
        exit 3
    fi
done

gh_api() {
    local method="$1" path="$2"
    shift 2
    echo "+ gh api -X $method $path $*"
    gh api -X "$method" "$path" "$@"
}

gh_api_json() {
    local method="$1" path="$2"
    echo "+ gh api -X $method $path --input -"
    gh api -X "$method" "$path" --input -
}

gh_api_json_file() {
    local method="$1" path="$2" file="$3"
    echo "+ gh api -X $method $path --input $file"
    gh api -X "$method" "$path" --input "$file"
}

try_gh_api() {
    local desc="$1"
    shift
    if ! "$@"; then
        echo "note: could not apply optional safeguard: $desc" >&2
    fi
}

ruleset_id_by_name() {
    local name="$1"
    gh api "repos/$repo/rulesets?includes_parents=false" \
        | jq -r --arg name "$name" '[.[] | select(.name == $name) | .id] | first // empty'
}

upsert_ruleset() {
    local name="$1" file="$2" id applied="$2"
    if command -v jq >/dev/null 2>&1 && [[ -n "${OWNER_ID:-}" ]]; then
        applied="$(mktemp)"
        jq --argjson oid "$OWNER_ID" '
            if has("bypass_actors")
            then .bypass_actors |= map(if .actor_type == "User" then .actor_id = $oid else . end)
            else . end
        ' "$file" > "$applied"
    fi
    id="$(ruleset_id_by_name "$name")"
    if [[ -n "$id" ]]; then
        gh_api_json_file PUT "repos/$repo/rulesets/$id" "$applied" >/dev/null
    else
        gh_api_json_file POST "repos/$repo/rulesets" "$applied" >/dev/null
    fi
    [[ "$applied" != "$file" ]] && rm -f "$applied"
}

require_live_value() {
    local desc="$1" actual="$2" expected="$3"
    if [[ "$actual" != "$expected" ]]; then
        echo "FAIL: $desc is '$actual', expected '$expected'" >&2
        exit 4
    fi
}

bash "$repo_root/tools/ruleset-check"

echo "Applying repository safeguards to $repo"

gh_api PATCH "repos/$repo" \
    -F allow_merge_commit=false \
    -F allow_squash_merge=true \
    -F allow_rebase_merge=false \
    -F allow_auto_merge=false \
    -F delete_branch_on_merge=true >/dev/null

upsert_ruleset "Protect main: integrity" "$integrity_ruleset"
upsert_ruleset "Protect main: review" "$review_ruleset"
upsert_ruleset "Protect main: owner updates" "$owner_updates_ruleset"

gh_api_json PUT "repos/$repo/branches/main/protection" <<'JSON' >/dev/null
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "ci"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON

try_gh_api "vulnerability alerts" \
    gh_api PUT "repos/$repo/vulnerability-alerts" --silent
try_gh_api "automated security fixes" \
    gh_api PUT "repos/$repo/automated-security-fixes" --silent
try_gh_api "secret scanning and push protection" \
    gh_api_json PATCH "repos/$repo" <<'JSON'
{
  "security_and_analysis": {
    "secret_scanning": {
      "status": "enabled"
    },
    "secret_scanning_push_protection": {
      "status": "enabled"
    }
  }
}
JSON

repo_settings="$(gh api "repos/$repo" \
    --jq '[.allow_merge_commit, .allow_squash_merge, .allow_rebase_merge, .allow_auto_merge, .delete_branch_on_merge] | @tsv')"
IFS=$'\t' read -r merge_allowed squash_allowed rebase_allowed auto_merge_allowed delete_branch_on_merge <<<"$repo_settings"
require_live_value "allow_merge_commit" "$merge_allowed" "false"
require_live_value "allow_squash_merge" "$squash_allowed" "true"
require_live_value "allow_rebase_merge" "$rebase_allowed" "false"
require_live_value "allow_auto_merge" "$auto_merge_allowed" "false"
require_live_value "delete_branch_on_merge" "$delete_branch_on_merge" "true"

integrity_id="$(ruleset_id_by_name "Protect main: integrity")"
review_id="$(ruleset_id_by_name "Protect main: review")"
owner_updates_id="$(ruleset_id_by_name "Protect main: owner updates")"
if [[ -z "$integrity_id" || -z "$review_id" || -z "$owner_updates_id" ]]; then
    echo "FAIL: expected rulesets were not found after apply" >&2
    exit 5
fi

integrity_bypass="$(gh api "repos/$repo/rulesets/$integrity_id" \
    --jq '.bypass_actors[] | "\(.actor_type):\(.actor_id):\(.bypass_mode)"')"
require_live_value "integrity bypass actor" "$integrity_bypass" "User:${OWNER_ID}:always"

review_bypass="$(gh api "repos/$repo/rulesets/$review_id" \
    --jq '.bypass_actors[] | "\(.actor_type):\(.actor_id):\(.bypass_mode)"')"
require_live_value "review bypass actor" "$review_bypass" "User:${OWNER_ID}:always"

owner_updates_bypass="$(gh api "repos/$repo/rulesets/$owner_updates_id" \
    --jq '.bypass_actors[] | "\(.actor_type):\(.actor_id):\(.bypass_mode)"')"
require_live_value "owner-updates bypass actor" "$owner_updates_bypass" "User:${OWNER_ID}:always"

bash "$repo_root/tools/ruleset-check" --repo "$repo" --owner-id "$OWNER_ID"

echo "Repository safeguards applied and verified. Re-run safely any time."
