#!/usr/bin/env bash
# (b) Turn manifest.json into a package.xml (entityName -> <name>, developerName[] -> <members>).
source "$(dirname "$0")/_common.sh"
[ -f "$OUT/manifest.json" ] || { echo "Run 01-get-manifest.sh first"; exit 1; }
jq -r --arg v "$API_VERSION" '
  def esc: gsub("&";"&amp;")|gsub("<";"&lt;")|gsub(">";"&gt;");
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Package xmlns=\"http://soap.sforce.com/2006/04/metadata\">",
  ( .dataKitMembers | group_by(.entityName)[]
    | "    <types>",
      ( [.[].developerName[]] | unique[] | "        <members>\(. | esc)</members>" ),
      "        <name>\(.[0].entityName)</name>",
      "    </types>" ),
  "    <version>\($v)</version>\n</Package>"' "$OUT/manifest.json" > "$OUT/package.xml"
log "Wrote $OUT/package.xml"; cat "$OUT/package.xml"
