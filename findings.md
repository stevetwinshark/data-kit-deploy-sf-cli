# Findings

Observed behavior (API v67.0 and v68.0, sandbox → sandbox). Add dated entries as you test.

## New Data Lake Object in a new kit — full run
- Dry run: all 7 kit metadata components reported **Created** (kit absent in target); validate-only deploy succeeded.
- Real run: metadata deploy succeeded; Connect `POST` `{DataLakeObject}` → `201 {jobId}`; target `deployment-status` → **ACTIVE**.
- Quirk: `deployment-status` must be queried by the kit component `developerName`, not the `__dll` API name (empty `componentDetails` otherwise).

## Ingestion API stream-bundle kit — validate only
- Manifest returned 9 entity types (24 components); validate-only deploy succeeded against a target that already held the kit (20 Unchanged, 4 Changed). Derived payload: one `DataStreamBundle` (`INGESTAPI`). Not POSTed.

## Multi-component kit with transforms — derive only
- DLOs derived and matched to their shells by label; `DataTransform` components skipped by design.

## API v67.0 → v68.0 comparison (read-only probes + validate-only deploy)
Same orgs, same kit; all results identical on v68.0 (the orgs' "Latest Release"):
- Singular `/ssot/datakit/{name}/manifest` → 200 (6 members); plural `/ssot/data-kits/{name}/manifest` → `NOT_FOUND`.
- `GET /ssot/data-kits` without `namespace` → still `INTERNAL_SERVER_ERROR`.
- `deployment-status` by kit developerName → `ACTIVE`; by `__dll` name → `{"componentDetails":[]}`.
- `POST /ssot/data-kits/{kit}` without `asyncMode` → `INVALID_INPUT: Sync mode unsupported at this time`.
- Payload derivation and validate-only metadata deploy (`--dry-run`) succeed; `package.xml` version 68.0.
- Not re-run on v68.0: a real (mutating) deploy.

## Re-deploy behavior
- `DataPackageKitDefinition` reports **Changed** on every re-deploy: `dataKitSource` is `LOCAL` (source) vs `EXTERNAL` (target, set by the platform on deploy). Everything else is Unchanged.
- `DataKitDeploymentLog` is keyed by the deploy POST's `jobId` (`JobIdentifier`): one `Successful` row per component plus one component-less row. Step e waits on this row — it proves *that* run finished, unlike `deployment-status`, which reports ACTIVE immediately for an already-active component.
