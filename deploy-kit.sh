#!/usr/bin/env bash
# One-command flow:  ./deploy-kit.sh <DataKitName> --from <sourceAlias> --to <targetAlias> [--dry-run] [--yes]
# Everything else is derived from the kit name. Orgs are the only other input (sf CLI aliases).
set -euo pipefail
cd "$(dirname "$0")"
KIT="${1:?usage: deploy-kit.sh <DataKitName> --from <alias> --to <alias> [--dry-run] [--yes]}"; shift
YES=0
while [ $# -gt 0 ]; do case "$1" in
  --from) SOURCE_ORG="$2"; shift 2;; --to) TARGET_ORG="$2"; shift 2;;
  --dry-run) DRY_RUN=1; shift;; --yes) YES=1; shift;; *) echo "unknown arg $1"; exit 2;; esac; done
export KIT SOURCE_ORG TARGET_ORG DRY_RUN="${DRY_RUN:-0}"
: "${SOURCE_ORG:?--from required}"; : "${TARGET_ORG:?--to required}"
if [ "$DRY_RUN" != "1" ] && [ "$YES" != "1" ]; then
  read -r -p "Deploy kit '$KIT' from $SOURCE_ORG to $TARGET_ORG? Type the target alias to confirm: " a
  [ "$a" = "$TARGET_ORG" ] || { echo aborted; exit 1; }
fi
scripts/run-all.sh
