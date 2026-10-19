"""Manifest fragments (one per generator, so parallel workers never overwrite each other)
and the deterministic merge into blender/manifest.json. Stdlib only.

Review verdicts live in blender/reviews/<generator>.json and are pinned to each asset's
geometry hash: if the geometry changes after a review, the asset drops back to
UNREVIEWED automatically.
"""

import json
import os
import re
import struct
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


# ---- FL-0136: the environment mesh kit (trees, bushes, rocks, nodes, crops) is gated the same way: every number env.json declares is MEASURED from the
# shipped FBX. Constants here on purpose (D-057 (19): trees 300-900 triangles; bushes, rocks and flowers 40-400 as in env_to_luau.py's header), independent of env.json.
ENV_LIMITS = {"tree": (300, 900), "bush": (40, 400), "rock": (40, 400), "flower": (40, 400), "crop": (40, 1500), "haystack": (40, 600), "fence": (40, 600)}
ENV_MESH_MAX = 20000
ENV_FIT = {"footprint": (0.85, 1.15), "node": (0.85, 1.02), "height": (0.75, 1.25)}  # the Kit's rule (art/env_kit/env_to_luau.py): footprint max(x, z), unless env.json gives the prop a `fit_note`
ENV_SINK_MAX = 0.6
ENV_PATH_RE = re.compile(r"(/home/|/Users/|/root/|/tmp/|/mnt/|/var/folders/|(?<![A-Za-z0-9])[A-Za-z]:[\\/][A-Za-z0-9_.-]+)")  # applied to the FBX's text values only (fbxtris.strings)
ENV_ID_RE = re.compile(r"^[a-z]+(?:_[a-z0-9]+)*_\d{2}$")  # the Kit validator's shape: lowercase, ends in _NN


def env_budget_errors(doc, measured, bounds=None):
    """Errors of an env.json document against what the FBX holds ({object name: triangles}, optionally {object name: vertex box}).

    Every prop: present in both, id shape, known family, declared `tris` equals measured and sits inside its family's budget, mesh <= 20,000, base not sunk further than
    0.6, the footprint and height within the Kit's window of its stand-in (or explained by `fit_note`), the declared box equal to the measured one."""
    errs = []
    props = doc.get("props", {})
    for k in sorted(set(props) - set(measured)):
        errs.append(f"prop {k} is in env.json but not in the FBX")
    for k in sorted(set(measured) - set(props)):
        errs.append(f"FBX object {k} is not a prop of env.json")
    for k in sorted(set(props) & set(measured)):
        p = props[k]
        fam = p.get("family")
        if not ENV_ID_RE.match(k):
            errs.append(f"prop {k}: not a valid asset id")
        if fam not in ENV_LIMITS:
            errs.append(f"prop {k}: unknown family {fam!r}")
            continue
        lo, hi = ENV_LIMITS[fam]
        if p.get("tris") != measured[k]:
            errs.append(f"prop {k}: env.json declares {p.get('tris')} triangles, the FBX has {measured[k]}")
        if not lo <= measured[k] <= hi:
            errs.append(f"prop {k}: {measured[k]} measured triangles outside the {fam} budget {lo}..{hi}")
        if not 1 <= measured[k] <= ENV_MESH_MAX:
            errs.append(f"prop {k}: {measured[k]} triangles is outside 1..{ENV_MESH_MAX}")
        if p.get("base_y", 0) < -ENV_SINK_MAX:
            errs.append(f"prop {k}: base_y {p.get('base_y')} sinks further than {ENV_SINK_MAX}")
        f = p.get("fit")
        if f and not p.get("fit_note"):
            lo, hi = ENV_FIT["node"] if p.get("node") else ENV_FIT["footprint"]
            if not lo <= f["footprint_ratio"] <= hi:
                errs.append(f"prop {k}: footprint {f['footprint']} vs stand-in {f['standin_footprint']} is outside {lo:.0%}-{hi:.0%} and has no fit_note")
            if not ENV_FIT["height"][0] <= f["height_ratio"] <= ENV_FIT["height"][1]:
                errs.append(f"prop {k}: height {f['height']} vs stand-in {f['standin_height']} is outside {ENV_FIT['height'][0]:.0%}-{ENV_FIT['height'][1]:.0%} and has no fit_note")
        if bounds and k in bounds:
            (x0, y0, z0), (x1, y1, z1) = bounds[k]
            size = [x1 - x0, z1 - z0, y1 - y0]  # Blender object space (z up) -> rig axes
            if max(abs(a - b) for a, b in zip(size, p.get("size", [0, 0, 0]))) > 0.02:
                errs.append(f"prop {k}: env.json size {p.get('size')} differs from the FBX vertices {[round(v, 3) for v in size]}")
    return errs


def env_kit_errors(a, repo=REPO):
    """Measure the committed FBX of the env kit row and compare everything it declares (env.json, the row's own `kit` summary, the file's sha256, no personal paths)."""
    import hashlib

    from . import fbxtris

    files = a.get("files") or {}
    if not files.get("env"):
        return []
    fbx, env = Path(repo) / files.get("mesh_committed", ""), Path(repo) / files["env"]
    if not fbx.is_file() or not env.is_file():
        return [f"{a['id']}: the committed FBX or env.json named by the row is missing ({files.get('mesh_committed')}, {files.get('env')})"]
    raw = fbx.read_bytes()
    errs = []
    try:
        texts = fbxtris.strings(fbx)
    except (fbxtris.FbxError, OSError, ValueError, IndexError, struct.error) as e:
        return [f"{a['id']}: cannot read the FBX: {e}"]
    for t in texts:  # node names and string properties only: binary vertex data is full of accidental byte pairs
        if ENV_PATH_RE.search(t):
            errs.append(f"{a['id']}: the FBX contains a path-like string ({t[:60]!r}): export without a personal path")
            break
    sha = hashlib.sha256(raw).hexdigest()
    doc = json.loads(env.read_text())
    if doc.get("fbx_sha256") != sha:
        errs.append(f"{a['id']}: env.json fbx_sha256 {str(doc.get('fbx_sha256'))[:12]} is not the sha256 of the committed FBX {sha[:12]}")
    kit = a.get("kit") or {}
    if kit.get("fbx_sha256") != sha:
        errs.append(f"{a['id']}: the row's kit.fbx_sha256 {str(kit.get('fbx_sha256'))[:12]} is not the sha256 of the committed FBX {sha[:12]}")
    try:
        measured = fbxtris.measure(fbx)
        bounds = fbxtris.measure_bounds(fbx)
    except (fbxtris.FbxError, OSError, ValueError, IndexError) as e:
        return errs + [f"{a['id']}: cannot read the FBX: {e}"]
    errs += [f"{a['id']}: {e}" for e in env_budget_errors(doc, measured, bounds)]
    if not errs:
        if kit.get("total_tris") != sum(measured.values()):
            errs.append(f"{a['id']}: kit.total_tris declares {kit.get('total_tris')}, the FBX has {sum(measured.values())}")
        if kit.get("max_mesh_tris") != max(measured.values()):
            errs.append(f"{a['id']}: kit.max_mesh_tris declares {kit.get('max_mesh_tris')}, the FBX has {max(measured.values())}")
        if kit.get("props") != len(measured):
            errs.append(f"{a['id']}: kit.props declares {kit.get('props')}, the FBX has {len(measured)} meshes")
    return errs


def kit_errors(a, repo=REPO):
    """Measure the committed FBX of a kit row and compare everything it declares (rig.json, the row's own `kit` summary)."""
    from . import fbxtris

    files = a.get("files") or {}
    if files.get("env") or not files.get("mesh_committed"):
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
        errs += env_kit_errors(a)
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
