#!/usr/bin/env bash
# (e) Derive the deploy body from the kit name, POST it to the TARGET org (asyncMode=true), poll status.
# Metadata deploy (step d) only lands kit definitions; streams/DLOs are NOT live until this POST.
source "$(dirname "$0")/_common.sh"
log "Derive deploy payload from source kit '$KIT'"
python3 "$ROOT/scripts/derive_payload.py" "$KIT" "$SOURCE_ORG" "$API_VERSION" "$OUT"
P="$OUT/deploy-payload.json"
[ "$(jq '.components|length' "$P")" -gt 0 ] || { echo "Nothing to activate via Connect (metadata-only kit?)."; exit 0; }
[ "${DRY_RUN:-0}" = "1" ] && { echo "DRY_RUN: payload at $P, not POSTing."; exit 0; }
log "POST deploy to $TARGET_ORG (asyncMode=true is required)"
rest "/services/data/v${API_VERSION}/ssot/data-kits/${KIT}?asyncMode=true" --method POST --body "@$P" --target-org "$TARGET_ORG" | tee "$OUT/deploy-response.json"
log "Poll deployment-status (async; tens of seconds is normal)"
# deployment-status is keyed by the kit component's developerName (e.g. 'Test1'), NOT the __dll api name
for c in $(cat "$OUT/poll-names.txt"); do
  for i in $(seq 1 12); do
    sleep 10
    s=$(rest "/services/data/v${API_VERSION}/ssot/data-kits/${KIT}/components/${c}/deployment-status" --target-org "$TARGET_ORG" 2>/dev/null | jq -r '.status.code // "unknown"' || echo unknown)
    echo "$c: $s"; [[ "$s" =~ ^(Active|ACTIVE|Failed|FAILED)$ ]] && break
  done
done
