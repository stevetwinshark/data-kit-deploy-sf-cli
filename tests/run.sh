#!/usr/bin/env bash
# Offline tests: no orgs, no network. Requires bash, jq, python3.
set -euo pipefail
T="$(cd "$(dirname "$0")" && pwd)"; ROOT="$T/.."; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# 1. manifest -> package.xml (grouping, de-dup, XML escaping, version)
mkdir -p "$ROOT/out/_test"; cp "$T/fixtures/manifest.json" "$ROOT/out/_test/manifest.json"
KIT=_test SOURCE_ORG=x TARGET_ORG=y API_VERSION=68.0 "$ROOT/scripts/02-build-package-xml.sh" >/dev/null
P="$ROOT/out/_test/package.xml"; rm -f "$TMP/_"
grep -q '<members>x&amp;y</members>' "$P" || fail "xml escaping"
grep -q '<version>68.0</version>' "$P" || fail "version"
[ "$(grep -c '<types>' "$P")" = 3 ] || fail "types grouping"
xmllint --noout "$P" 2>/dev/null || python3 -c "import xml.dom.minidom,sys;xml.dom.minidom.parse(sys.argv[1])" "$P" || fail "well-formed xml"
rm -rf "$ROOT/out/_test"

# 2. payload derivation (offline via KIT_JSON)
KIT_JSON="$T/fixtures/kit.json" python3 "$ROOT/scripts/derive_payload.py" Demo none 68.0 "$TMP" >"$TMP/log"
jq -e '.components|length==2' "$TMP/deploy-payload.json" >/dev/null || fail "component count"
jq -e '.components[]|select(.type=="DataLakeObject")|.config.apiName=="Airport_Enriched__dll" and .config.dataSpaceName=="default"' "$TMP/deploy-payload.json" >/dev/null || fail "DLO config"
jq -e '.components[]|select(.type=="DataStreamBundle")|.config.connectorType=="INGESTAPI" and .config.bundleConfig.connectorName=="MyIngest"' "$TMP/deploy-payload.json" >/dev/null || fail "bundle config"
grep -q "DataTransform" "$TMP/log" || fail "transform should be reported as skipped"
grep -q "DataModelObject" "$TMP/log" || fail "DMO should be reported as omitted"
bash -n "$ROOT"/scripts/*.sh "$ROOT/deploy-kit.sh"
echo "All tests passed."
