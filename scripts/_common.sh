#!/usr/bin/env bash
# Shared setup. Source from each script.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/config.sh" ] && source "$ROOT/config.sh"
: "${KIT:?set KIT}"
: "${SOURCE_ORG:?set SOURCE_ORG (sf alias)}"
: "${TARGET_ORG:?set TARGET_ORG (sf alias)}"
# API version: use API_VERSION if set; otherwise the highest version BOTH orgs support (newest GA release common to each).
latest_api() { sf api request rest /services/data --target-org "$1" 2>/dev/null | jq -r '[.[].version|tonumber]|max|tostring|if test("\\.") then . else .+".0" end'; }
if [ -z "${API_VERSION:-}" ]; then
  s="$(latest_api "$SOURCE_ORG")"; t="$(latest_api "$TARGET_ORG")"
  [ -n "$s" ] && [ -n "$t" ] || { echo "Could not detect API versions; set API_VERSION"; exit 1; }
  API_VERSION="$(printf '%s\n%s\n' "$s" "$t" | sort -n | head -1)"
fi
export API_VERSION
OUT="$ROOT/out/$KIT"
mkdir -p "$OUT"
cd "$ROOT"
log() { printf '\n==> %s\n' "$*"; }
# GET/POST against the Connect API using the sf CLI's own auth (no tokens handled here)
rest() { sf api request rest "$@"; }
