#!/usr/bin/env bash
# Runs a–e in order. Set DRY_RUN=1 to validate the metadata deploy and skip step e.
D="$(dirname "$0")"
"$D/01-get-manifest.sh"; "$D/02-build-package-xml.sh"; "$D/03-retrieve.sh"; "$D/04-deploy.sh"
[ "${DRY_RUN:-0}" = "1" ] || "$D/05-trigger-kit-deploy.sh"
