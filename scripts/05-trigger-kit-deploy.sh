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
JOB="$(jq -r '.jobId // empty' "$OUT/deploy-response.json")"
[ -n "$JOB" ] || { echo "No jobId in response — deploy was not accepted."; exit 1; }
log "Wait for job $JOB in DataKitDeploymentLog (async; tens of seconds is normal)"
# The log row is keyed by this POST's jobId, so it proves *this* run finished (deployment-status can't:
# a component that was already ACTIVE reports ACTIVE immediately).
for i in $(seq 1 30); do
  sleep 10
  rows="$(sf data query --target-org "$TARGET_ORG" --result-format json \
    --query "SELECT DeploymentStatus, ComponentName, DeploymentError FROM DataKitDeploymentLog WHERE JobIdentifier = '$JOB'" 2>/dev/null \
    | jq -c '[.result.records[] | {s: .DeploymentStatus, c: .ComponentName, e: .DeploymentError}]' || echo '[]')"
  [ "$rows" = "[]" ] && { echo "  waiting (no log rows yet)…"; continue; }
  echo "  $rows"
  if jq -e 'all(.[]; .s != "Started" and .s != null)' <<<"$rows" >/dev/null; then
    if jq -e 'all(.[]; .s == "Successful" and .e == null)' <<<"$rows" >/dev/null; then
      log "Deploy job $JOB: Successful"
      for c in $(jq -r '.[].c | select(. != null)' <<<"$rows"); do   # informational; keyed by kit component developerName
        echo "  $c: $(rest "/services/data/v${API_VERSION}/ssot/data-kits/${KIT}/components/${c}/deployment-status" --target-org "$TARGET_ORG" 2>/dev/null | jq -r '.status.code // "unknown"')"
      done
      exit 0
    fi
    echo "Deploy job $JOB FAILED:"; jq . <<<"$rows"; exit 1
  fi
done
echo "Timed out waiting for job $JOB (still running? check DataKitDeploymentLog)."; exit 2
