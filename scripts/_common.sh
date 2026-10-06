#!/usr/bin/env bash
# Shared setup. Source from each script.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ -f "$ROOT/config.sh" ] && source "$ROOT/config.sh"
: "${KIT:?set KIT}"
: "${SOURCE_ORG:?set SOURCE_ORG (sf alias)}"
: "${TARGET_ORG:?set TARGET_ORG (sf alias)}"
API_VERSION="${API_VERSION:-67.0}"
OUT="$ROOT/out/$KIT"
mkdir -p "$OUT"
cd "$ROOT"
log() { printf '\n==> %s\n' "$*"; }
# GET/POST against the Connect API using the sf CLI's own auth (no tokens handled here)
rest() { sf api request rest "$@"; }
