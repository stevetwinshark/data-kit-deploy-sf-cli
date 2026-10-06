# Findings

Observed behavior (API v67.0, sandbox → sandbox). Add dated entries as you test.

## New Data Lake Object in a new kit — full run
- Dry run: all 7 kit metadata components reported **Created** (kit absent in target); validate-only deploy succeeded.
- Real run: metadata deploy succeeded; Connect `POST` `{DataLakeObject}` → `201 {jobId}`; target `deployment-status` → **ACTIVE**.
- Quirk: `deployment-status` must be queried by the kit component `developerName`, not the `__dll` API name (empty `componentDetails` otherwise).

## Ingestion API stream-bundle kit — validate only
- Manifest returned 9 entity types (24 components); validate-only deploy succeeded against a target that already held the kit (20 Unchanged, 4 Changed). Derived payload: one `DataStreamBundle` (`INGESTAPI`). Not POSTed.

## Multi-component kit with transforms — derive only
- DLOs derived and matched to their shells by label; `DataTransform` components skipped by design.
