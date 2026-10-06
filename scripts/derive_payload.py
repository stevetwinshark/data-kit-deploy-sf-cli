#!/usr/bin/env python3
"""Derive the Connect deploy body (components[]) from the kit name alone.

Source of truth: GET /ssot/data-kits/{kit} on the SOURCE org (lists components with componentType,
connectorType, developerName, label). Rules (reverse-engineered; see README for verification status):
  DataStreamBundle -> {bundleName, connectorType, bundleConfig:{connectorName}}
  DataLakeObject   -> {dataSourceObjectDevName, apiName, label, dataSpaceName}
  DataActionTarget -> {apiName, label}
  DataModelObject  -> omitted (rides on metadata deploy; not in the deploy enum)
  DataTransform / others -> NOT derived; reported so you can handle them (transform deploy is unreliable).
Entries with no componentType are child objects (DSO/DLO shells) and are not deploy roots.
"""
import json, re, subprocess, sys, os

kit, src, api = sys.argv[1], sys.argv[2], sys.argv[3]
out = sys.argv[4]
space = os.environ.get("DATA_SPACE", "default")

def get(path):
    r = subprocess.run(["sf", "api", "request", "rest", path, "-o", src], capture_output=True, text=True)
    txt = "\n".join(l for l in r.stdout.splitlines() if "Warning" not in l)
    if r.returncode: sys.exit(r.stderr or txt)
    return json.loads(txt)

d = get(f"/services/data/v{api}/ssot/data-kits/{kit}")["dataKitDetails"][0]
json.dump(d, open(os.path.join(out, "kit-source.json"), "w"), indent=2)
comps = d["components"]
norm = lambda s: re.sub(r"[^a-z0-9]", "", re.sub(r"__dll$", "", s.lower()))
shells = [c for c in comps if not c.get("componentType")]  # label like "Airport_Enriched__dll"

body, skipped, poll = [], [], []
for c in comps:
    t, name = c.get("componentType"), c["developerName"]
    if t == "DataStreamBundle":
        body.append({"type": t, "config": {"bundleName": name, "connectorType": c["connectorType"],
                                           "bundleConfig": {"connectorName": name}}}); poll.append(name)
    elif t == "DataLakeObject":
        m = [s for s in shells if norm(s["label"]) == norm(c["label"])]
        if len(m) != 1:
            skipped.append((t, name, f"cannot uniquely match DLO shell by label ({len(m)} matches)")); continue
        api_name = m[0]["label"] if m[0]["label"].endswith("__dll") else m[0]["label"] + "__dll"
        body.append({"type": t, "config": {"dataSourceObjectDevName": api_name, "apiName": api_name,
                                           "label": c["label"], "dataSpaceName": space}}); poll.append(name)
    elif t == "DataActionTarget":
        body.append({"type": t, "config": {"apiName": name, "label": c["label"]}}); poll.append(name)
    elif t == "DataModelObject":
        skipped.append((t, name, "metadata-only; live after sf deploy"))
    elif t:
        skipped.append((t, name, "no verified deploy shape — handle manually"))

json.dump({"components": body}, open(os.path.join(out, "deploy-payload.json"), "w"), indent=2)
open(os.path.join(out, "poll-names.txt"), "w").write("\n".join(poll)+"\n")
print(f"Derived {len(body)} deployable component(s):")
for b in body: print("  +", b["type"], b["config"].get("bundleName") or b["config"].get("apiName"))
for s in skipped: print("  -", *s)
