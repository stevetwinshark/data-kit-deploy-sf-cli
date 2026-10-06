#!/usr/bin/env bash
# (d) sf project deploy of the retrieved metadata to the target org.
# DRY_RUN=1 -> validate only (--dry-run).
source "$(dirname "$0")/_common.sh"
FLAGS=(--manifest "$OUT/package.xml" --target-org "$TARGET_ORG" --wait 30)
[ "${DRY_RUN:-0}" = "1" ] && FLAGS+=(--dry-run) && log "VALIDATE ONLY (dry run)"
log "Deploy to $TARGET_ORG"
sf project deploy start "${FLAGS[@]}"
