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


def check(manifest_path=MANIFEST):
    """Schema + cross-checks used by check.sh. Returns a list of error strings."""
    data = json.loads(Path(manifest_path).read_text())
    errs = schema.validate(data, json.loads(SCHEMA.read_text()))
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
