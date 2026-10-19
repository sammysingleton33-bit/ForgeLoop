"""Manifest fragments (one per generator, so parallel workers never overwrite each other)
and the deterministic merge into blender/manifest.json. Stdlib only.

Review verdicts live in blender/reviews/<generator>.json and are pinned to each asset's
geometry hash: if the geometry changes after a review, the asset drops back to
UNREVIEWED automatically.
"""

import json
import os
from pathlib import Path

from . import palette, schema

ROOT = Path(__file__).resolve().parent.parent
FRAG_DIR = ROOT / "manifest.d"
REVIEW_DIR = ROOT / "reviews"
MANIFEST = ROOT / "manifest.json"
SCHEMA = ROOT / "manifest.schema.json"
SCHEMA_VERSION = 1


def _dump(data):
    return json.dumps(data, indent=2, sort_keys=True) + "\n"


def _atomic_write(path, text):
    """Write via a temp file + rename so parallel builds never read a half-written file."""
    path = Path(path)
    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(text)
    os.replace(tmp, path)


def review_for(generator, asset_id, geometry_hash):
    path = REVIEW_DIR / f"{generator}.json"
    if not path.exists():
        return {"verdict": "UNREVIEWED"}
    rev = json.loads(path.read_text())
    a = rev.get("assets", {}).get(asset_id)
    if not a:
        return {"verdict": "UNREVIEWED", "notes": "no review entry for this asset id"}
    if a.get("geometry_hash") != geometry_hash:
        return {"verdict": "UNREVIEWED", "notes": "geometry changed since the last review",
                "review_file": f"reviews/{generator}.md"}
    out = {"verdict": a["verdict"], "reviewer": rev.get("reviewer", ""), "round": int(rev.get("round", 0)),
           "review_file": f"reviews/{generator}.md"}
    scores = a.get("scores") or rev.get("scores")
    if scores:
        out["scores"] = {k: int(v) for k, v in scores.items()}
    notes = a.get("notes") or rev.get("notes")
    if notes:
        out["notes"] = notes
    return out


def write_fragment(generator, entries, variation, build=None):
    FRAG_DIR.mkdir(parents=True, exist_ok=True)
    frag = {"generator": generator, "variation": variation, "build": build or {},
            "assets": sorted(entries, key=lambda e: e["id"])}
    path = FRAG_DIR / f"{generator}.json"
    _atomic_write(path, _dump(frag))
    return path


def refresh_reviews():
    """Re-apply review files to every fragment (after a review is recorded)."""
    for path in sorted(FRAG_DIR.glob("*.json")):
        frag = json.loads(path.read_text())
        for e in frag["assets"]:
            e["review"] = review_for(frag["generator"], e["id"], e["geometry_hash"])
        _atomic_write(path, _dump(frag))


def merge():
    assets = []
    seen = {}
    for path in sorted(FRAG_DIR.glob("*.json")):
        frag = json.loads(path.read_text())
        for e in frag["assets"]:
            if e["id"] in seen:
                raise ValueError(f"duplicate asset id {e['id']} in {path.name} and {seen[e['id']]}")
            seen[e["id"]] = path.name
            assets.append(e)
    data = {
        "schema_version": SCHEMA_VERSION,
        "palette": {"file": f"exports/textures/forge_palette_v{palette.PALETTE_VERSION}.png",
                    "px": palette.SIZE, "version": palette.PALETTE_VERSION},
        "assets": sorted(assets, key=lambda e: e["id"]),
    }
    errs = schema.validate(data, json.loads(SCHEMA.read_text()))
    if errs:
        raise ValueError("manifest schema errors:\n  " + "\n  ".join(errs[:30]))
    _atomic_write(MANIFEST, _dump(data))
    return data


def fragments():
    return [json.loads(p.read_text()) for p in sorted(FRAG_DIR.glob("*.json"))]


ALLOWED_LICENSES = ("CC0-1.0", "project-original")
REPO = ROOT.parent


def provenance_errors(a, repo=REPO):
    """D-057 (13)/(14), FORGE-07 A1/A4: every committed row names its licence; a third-party (CC0) row also names the
    source URL, a pinned commit or date, the sha256 of each source file it was derived from, and ships the licence text.
    Only CC0-1.0 or the explicit project-original marker is accepted."""
    errs = []
    aid = a.get("id", "?")
    lic = a.get("license")
    if not lic:
        return [f"{aid}: missing license"]
    if lic not in ALLOWED_LICENSES:
        errs.append(f"{aid}: license {lic!r} is not one of {ALLOWED_LICENSES}")
    if lic == "CC0-1.0":
        for k in ("source_url", "source_date", "license_file"):
            if not a.get(k):
                errs.append(f"{aid}: CC0 row without {k}")
        files = a.get("source_files") or {}
        if not files and not a.get("source_sha256"):
            errs.append(f"{aid}: CC0 row without source_sha256 / source_files")
        if a.get("license_file") and not (Path(repo) / a["license_file"]).exists():
            errs.append(f"{aid}: license_file {a['license_file']} is not committed")
        if not a.get("source_commit") and not a.get("source_date"):
            errs.append(f"{aid}: CC0 row without a pinned source_commit or source_date")
    return errs


# ---- FORGE-07: the character kit's budgets are MEASURED from the shipped FBX, not read from a declared number.
# Constants here on purpose: they are the D-057 amended (11) limits, independent of anything rig.json declares about itself.
KIT_LIMITS = {"citizen": 1000, "citizen_body": 900, "citizen_tool": 150, "ruler": 1500, "pieces": 16, "mesh": 20000}
KIT_TOOL_JOINTS = ("Tool", "TorsoTool")
KIT_KINGDOMS = ("crimson", "azure", "emerald", "gold")


def kit_looks(sample=None):
    """Every look of G13.2 (6 skins x 6 hair styles x 8 hair colours x 6 outfits = 1,728), or a deterministic sample of `sample`."""
    allv = [{"skin": s, "hair": h, "hairColor": hc, "outfit": o} for s in range(1, 7) for h in range(1, 7) for hc in range(1, 9) for o in range(1, 7)]
    return allv if not sample else allv[:: max(1, len(allv) // sample)]


def kit_budget_errors(doc, measured, looks=None):
    """Errors of a rig.json document against triangle counts measured from the FBX ({object name: triangles}).

    Every piece: present in both, declared `tris` equals measured, 1..20,000. Every assembly x look x kingdom: pieces <= 16
    (a mirrored piece counts twice); a citizen <= 1,000 triangles in all, body <= 900, hand tool / sack <= 150; soldiers and
    governors <= 1,500 in all."""
    from . import ckit_resolve

    errs = []
    pieces = doc.get("pieces", {})
    solid = {k for k, v in pieces.items() if not v.get("empty")}
    for k in sorted(solid - set(measured)):
        errs.append(f"piece {k} is in rig.json but not in the FBX")
    for k in sorted(set(measured) - solid):
        errs.append(f"FBX object {k} is not a piece of rig.json")
    for k in sorted(solid & set(measured)):
        if pieces[k].get("tris") != measured[k]:
            errs.append(f"piece {k}: rig.json declares {pieces[k].get('tris')} triangles, the FBX has {measured[k]}")
        if not 1 <= measured[k] <= KIT_LIMITS["mesh"]:
            errs.append(f"piece {k}: {measured[k]} triangles is outside 1..{KIT_LIMITS['mesh']}")
    if errs:
        return errs
    worst = {}
    for key in doc.get("assemblies", {}):
        big = key == "governor" or key.startswith("soldier")
        for kd in KIT_KINGDOMS:
            for lk in looks or kit_looks():
                try:
                    ids = ckit_resolve.resolve_assembly(doc["assemblies"], pieces, key, lk, kd)
                except KeyError as e:
                    errs.append(f"{key}: {e}")
                    break
                total = sum(measured[i] for i in ids)
                tool = sum(measured[i] for i in ids if pieces[i].get("joint") in KIT_TOOL_JOINTS)
                n = sum(2 if pieces[i].get("mirror") else 1 for i in ids)
                w = worst.setdefault(key, [0, 0, 0])
                w[0], w[1], w[2] = max(w[0], total), max(w[1], tool), max(w[2], n)
    for key, (total, tool, n) in worst.items():
        big = key == "governor" or key.startswith("soldier")
        if big and total > KIT_LIMITS["ruler"]:
            errs.append(f"{key}: {total} measured triangles over the {KIT_LIMITS['ruler']} budget")
        if not big:
            if total > KIT_LIMITS["citizen"]:
                errs.append(f"{key}: {total} measured triangles over the citizen budget {KIT_LIMITS['citizen']}")
            if total - tool > KIT_LIMITS["citizen_body"]:
                errs.append(f"{key}: body {total - tool} measured triangles over {KIT_LIMITS['citizen_body']}")
            if tool > KIT_LIMITS["citizen_tool"]:
                errs.append(f"{key}: tool {tool} measured triangles over {KIT_LIMITS['citizen_tool']}")
        if n > KIT_LIMITS["pieces"]:
            errs.append(f"{key}: {n} pieces over {KIT_LIMITS['pieces']}")
    return errs


def kit_errors(a, repo=REPO):
    """Measure the committed FBX of a kit row and compare everything it declares (rig.json, the row's own `kit` summary)."""
    from . import fbxtris

    files = a.get("files") or {}
    if not files.get("mesh_committed"):
        return []
    fbx, rig = Path(repo) / files["mesh_committed"], Path(repo) / files.get("rig", "")
    if not fbx.exists() or not rig.is_file():
        return [f"{a['id']}: the committed FBX or rig.json named by the row is missing ({files.get('mesh_committed')}, {files.get('rig')})"]
    try:
        measured = fbxtris.measure(fbx)
    except (fbxtris.FbxError, OSError, ValueError, IndexError) as e:
        return [f"{a['id']}: cannot read the FBX: {e}"]
    doc = json.loads(rig.read_text())
    errs = [f"{a['id']}: {e}" for e in kit_budget_errors(doc, measured)]
    if not errs:  # the row's own numbers must equal the measurement
        kit = a.get("kit") or {}
        pieces = doc["pieces"]
        from . import ckit_resolve

        for key in doc["assemblies"]:
            big = key == "governor" or key.startswith("soldier")
            hi = max(sum(measured[i] for i in ckit_resolve.resolve_assembly(doc["assemblies"], pieces, key, lk, kd))
                     for kd in KIT_KINGDOMS for lk in kit_looks())
            if kit.get("jobs", {}).get(key, {}).get("tris_max") != hi:
                errs.append(f"{a['id']}: kit.jobs.{key}.tris_max declares {kit.get('jobs', {}).get(key, {}).get('tris_max')}, measured {hi}")
        if kit.get("total_piece_tris") != sum(measured.values()):
            errs.append(f"{a['id']}: kit.total_piece_tris declares {kit.get('total_piece_tris')}, the FBX has {sum(measured.values())}")
    return errs


def check(manifest_path=MANIFEST):
    """Schema + cross-checks used by check.sh. Returns a list of error strings."""
    data = json.loads(Path(manifest_path).read_text())
    errs = schema.validate(data, json.loads(SCHEMA.read_text()))
    for a in data.get("assets", []):
        errs += provenance_errors(a)
        errs += kit_errors(a)
    ids = [a["id"] for a in data.get("assets", [])]
    if len(ids) != len(set(ids)):
        errs.append("duplicate ids in manifest")
    if ids != sorted(ids):
        errs.append("manifest assets not sorted by id (merge is not deterministic)")
    for a in data.get("assets", []):
        if a["triangles"]["lod0"] > a["triangles"]["budget_lod0"]:
            errs.append(f"{a['id']}: lod0 {a['triangles']['lod0']} over budget {a['triangles']['budget_lod0']}")
        if not a["validation_pass"]:
            errs.append(f"{a['id']}: validation failed (see {a['files']['validation']})")
        if not a["id"].startswith(a["category"] + "_"):
            errs.append(f"{a['id']}: id must start with its category {a['category']!r}")
    return errs


def warnings(manifest_path=MANIFEST):
    """Non-fatal findings printed by check.sh: previews the manifest names but the repo does not carry
    (generators write them to blender/previews/ when someone runs a render; exports/ is gitignored)."""
    data = json.loads(Path(manifest_path).read_text())
    return [
        f"{a['id']}: preview {a['preview']} is not committed"
        for a in data.get("assets", [])
        if a.get("preview") and not (ROOT / a["preview"]).exists()
    ]
