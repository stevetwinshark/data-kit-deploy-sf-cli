#!/usr/bin/env bash
# (c) sf project retrieve using the generated package.xml (source org) -> ./force-app (gitignored)
source "$(dirname "$0")/_common.sh"
log "Retrieve from $SOURCE_ORG"
sf project retrieve start --manifest "$OUT/package.xml" --target-org "$SOURCE_ORG" --wait 20
