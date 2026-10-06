# data-kit-deploy-sf-cli

Move a **Data 360 Data Kit** from one Salesforce org to another using only the `sf` CLI and a few shell/Python
scripts — give it a kit name and two org aliases.

> **Experimental.** Every endpoint used here is part of the documented Data 360 Connect API (see
> [Salesforce documentation](#salesforce-documentation)). What makes it fragile is that the documentation is thin or
> inconsistent in places (see [Where the docs and behavior diverge](#where-the-docs-and-behavior-diverge)), and that
> the deploy request bodies are *derived* from kit contents because no endpoint returns a ready-made one. Exercised on
> API v67.0 and v68.0 against sandboxes only; expect to adjust between releases.

| Step | Script | What |
|---|---|---|
| a | `01-get-manifest.sh` | Fetch the kit's manifest **by name** from the Data Kit Component API (`GET /ssot/datakit/{name}/manifest`) |
| b | `02-build-package-xml.sh` | Convert the manifest into a `package.xml` |
| c | `03-retrieve.sh` | `sf project retrieve start --manifest` from the source org |
| d | `04-deploy.sh` | `sf project deploy start --manifest` to the target org (`DRY_RUN=1` validates only) |
| e | `05-trigger-kit-deploy.sh` | Derive the deploy body from the kit, `POST /ssot/data-kits/{name}?asyncMode=true`, poll `deployment-status` |

## Purpose and safety
This is a **diagnostic tool for isolating deployment problems** ("is it the metadata, the platform, or the pipeline?").
It is **not a replacement for your release pipeline**: anything deployed this way is outside your pipeline's tracking.

- **Use sandboxes / scratch orgs only. Never point it at production.**
- **Run `--dry-run` first.** The real run asks you to type the target alias to confirm (`--yes` skips this).
- No credentials are read or stored; REST calls go through `sf api request rest` using the CLI's own auth.

## Requirements
`sf` CLI (authenticated to both orgs), `bash`, `jq`, `python3` (stdlib only). macOS/Linux; on Windows use WSL.

## API version
By default the tools use the **highest API version both orgs support** (read from `GET /services/data` on each org; the
lower of the two wins). Override with `API_VERSION=68.0`. The `package.xml` `<version>` and every Connect call use it.
`sourceApiVersion` in `sfdx-project.json` is static (68.0) — update it when you move to a newer release.

## Usage
```bash
sf org login web --alias source-sandbox      # once per org
sf org login web --alias target-sandbox
./deploy-kit.sh MyKit --from source-sandbox --to target-sandbox --dry-run   # a–d validate; e derives payload, no POST
./deploy-kit.sh MyKit --from source-sandbox --to target-sandbox             # full run
```
Individual steps: `scripts/01…05` with `KIT`, `SOURCE_ORG`, `TARGET_ORG` set (see `config.sh.example`).
Retrieved metadata lands in `force-app/` and run artifacts in `out/<kit>/` (both gitignored — they contain your org's metadata).

## Step e: derived payload
`scripts/derive_payload.py` reads `GET /ssot/data-kits/{kit}` from the source and maps each component:

| componentType | Deploy body | Status |
|---|---|---|
| `DataLakeObject` | `{dataSourceObjectDevName, apiName, label, dataSpaceName}` | **Run end to end** (new DLO, kit absent in target → component ACTIVE). The `__dll` name is inferred by matching the kit's DLO shell by label; `DATA_SPACE` env overrides `default`. |
| `DataStreamBundle` | `{bundleName, connectorType, bundleConfig:{connectorName}}` | Payload derived and validated against real kits; body shape seen working in earlier manual testing for `INGESTAPI`. `connectorName == bundleName` is an **assumption**; other connector types untested. |
| `DataActionTarget` | `{apiName, label}` | Shape seen working in manual testing; not exercised by this tool. |
| `DataModelObject` | omitted | Goes live with the metadata deploy; not accepted by the kit deploy endpoint. |
| `DataTransform`, others | **not derived** (reported as skipped) | Transform deploys were unreliable in testing; handle separately. |

## Where the docs and behavior diverge
The operations are all documented in the Connect API reference; these are the rough edges found while using them
(each reproduced on v67.0 and v68.0):

- **Inconsistent manifest path (spec quirk).** The reference documents it as singular, `/ssot/datakit/{dataKitDevName}/manifest`,
  while every sibling operation is under `/ssot/data-kits/…`. The "obvious" `/ssot/data-kits/{name}/manifest` returns 404.
- **`asyncMode=true` is required on deploy (documented), but the error is misleading.** Omitting it returns
  `INVALID_INPUT: Sync mode unsupported at this time`, which reads like a feature flag rather than a missing parameter.
- **`componentName` is under-specified for `deployment-status`.** The reference says only "Name of the component". In practice it
  must be the kit component's `developerName` (e.g. `Test1`), not the deploy-body `apiName` (`Test1__dll`); the wrong one returns
  an empty `componentDetails` with no error.
- **Get data kits (list) returned a 500** when called without the `namespace` parameter (documented as optional; it filters by
  *package* namespace). List kits with a Tooling query on `DataPackageKitDefinition` instead.
- **No per-kit deploy body.** The reference documents the request schema per component type, but nothing returns the right body
  for an existing kit, so this tool derives it (hence "experimental").
- **`DataPackageKitDefinition` always shows as Changed on re-deploy.** `dataKitSource` is `LOCAL` in the source org and becomes
  `EXTERNAL` in the target after deploy. Expected; not a sign of drift.
- **Not carried by kits:** DMO→DLO field mappings. Repair them in the target.
- **Documented but unused here:** the deploy operation accepts a `dataspace` query parameter (defaults to `default` per the reference);
  this tool instead sets `dataSpaceName` in each DLO's deploy config.

## Tests
`tests/run.sh` runs offline (no org needed): it checks the manifest → `package.xml` conversion and the payload derivation
against saved fixtures.

See `findings.md` for observed behavior. Contributions and corrections welcome.

## Salesforce documentation
Official references for the APIs and concepts used here (the contents of the Developer Guide pages were not verified
by this project — check them for current version availability):
- [Use CLI to Deploy Changes from a Sandbox to Data 360](https://developer.salesforce.com/docs/data/data-cloud-dev/guide/dc-deploy_data_kit_using_cli.html) — Salesforce's own CLI-based data kit deploy guide
- [Deploy Data Kit Components by Using the Deploy Data Kit Components Flow](https://developer.salesforce.com/docs/data/data-cloud-dev/guide/dc-deploy_data_kit_components.html)
- [Data 360 Connect API reference (spec)](https://developer.salesforce.com/docs/data/connectapi/references/spec) — data kit resources: get/create/delete data kits, get available components, update components, deploy components, get manifest, undeploy, component dependencies and status
- [Data 360 Connect API overview](https://developer.salesforce.com/docs/data/connectapi/overview)
- [Data Kits (Salesforce Help)](https://help.salesforce.com/s/articleView?id=sf.c360_a_data_package_kits.htm&language=en_US&type=5) — standard vs. DevOps data kits
- [Build and Share Data 360 Functionality (Salesforce Help)](https://help.salesforce.com/s/articleView?id=c360_a_build_and_share_functionality.htm&type=5&language=en_US)
- [How API Version and Source API Version Work in Salesforce CLI](https://developer.salesforce.com/docs/platform/sfdx-setup/guide/sfdx-setup-apiversion.html)

Per Salesforce's documentation, the get-manifest operation is available from API v63.0 and deploy-components from v64.0
(deploy requires `asyncMode=true`). **DevOps data kits** (sandbox → another org) are deployed to the *same data space*
name in the target org, so the data space must exist there; this tool defaults `dataSpaceName` to `default`.

## License
MIT — see `LICENSE`.
