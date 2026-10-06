#!/usr/bin/env bash
# (a) Retrieve a Data Kit's manifest BY NAME from the Data Kit Component API (source org).
# NOTE: manifest path is /ssot/datakit/{name}/manifest (singular, no hyphen) — a documented Salesforce spec quirk.
source "$(dirname "$0")/_common.sh"
log "GET manifest for kit '$KIT' from $SOURCE_ORG"
rest "/services/data/v${API_VERSION}/ssot/datakit/${KIT}/manifest" --target-org "$SOURCE_ORG" > "$OUT/manifest.json"
jq -r '.dataKitMembers[] | "\(.entityName)\t\(.developerName|join(", "))"' "$OUT/manifest.json" | column -t -s$'\t'
