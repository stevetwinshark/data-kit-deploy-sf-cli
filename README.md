# data-kit-deploy-sf-cli

Move a **Data 360 Data Kit** from one Salesforce org to another using only the `sf` CLI and a few shell/Python
scripts — give it a kit name and two org aliases.

> **Experimental.** This relies on Connect API behavior that is undocumented or differs from the published spec
> (see [Known quirks](#known-quirks)), and the deploy payloads are reverse-engineered. It has been exercised on
> API v67.0 against sandboxes only. Expect it to break between releases.

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
| `DataStreamBundle` | `{bundleName, connectorType, bundleConfig:{connectorName}}` | Payload derived and validated against real kits; body shape seen working in manual testing for `INGESTAPI`. `connectorName == bundleName` is an **assumption**; other connector types untested. |
| `DataActionTarget` | `{apiName, label}` | Shape seen working in manual testing; not exercised by this tool. |
| `DataModelObject` | omitted | Goes live with the metadata deploy; not accepted by the kit deploy endpoint. |
| `DataTransform`, others | **not derived** (reported as skipped) | Transform deploys were unreliable in testing; handle separately. |

## Known quirks
- Manifest path is singular, `/ssot/datakit/{name}/manifest`; `/ssot/data-kits/{name}/manifest` returns 404.
- `asyncMode=true` is required on deploy; omitting it returns a misleading "Sync mode unsupported" error.
- Deploy is async — allow tens of seconds.
- `deployment-status/{componentName}` is keyed by the kit component's `developerName` (e.g. `Test1`), not the deploy-body `apiName` (`Test1__dll`); the wrong one returns an empty `componentDetails` with no error.
- `GET /ssot/data-kits` (list) with no `namespace` returned a 500 in testing; list kits via a Tooling query on `DataPackageKitDefinition` instead.
- DMO→DLO field mappings are not carried by kits; repair them in the target.

See `findings.md` for observed behavior. Contributions and corrections welcome.

## License
MIT — see `LICENSE`.
