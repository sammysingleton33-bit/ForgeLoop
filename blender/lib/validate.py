"""Per-asset validation report (written as <asset_id>.validation.json next to the export).

Checks: triangle budget + Roblox 20k per-mesh limit, size limit, bounds in studs (Roblox
X/Y/Z, Y up), pivot at base centre, degenerate faces, loose vertices, open edges (Roblox
wants watertight meshes with no zero-thickness surfaces; we use solid geometry, no alpha
cards), one UV map in 0..1 that only samples used palette swatches, one material, and the
generator's structural anti-primitive checks.
"""

import json
import math
from pathlib import Path

import bmesh
import numpy as np

from . import palette
from .export import size_to_roblox

ROOT = Path(__file__).resolve().parent.parent
BUDGETS = json.loads((ROOT / "budgets.json").read_text())


def budget_for(cls):
    if cls not in BUDGETS["classes"]:
        raise KeyError(f"unknown budget class {cls!r} (blender/budgets.json)")
    return BUDGETS["classes"][cls]


def _structural(stats, checks):
    out = []
    for key, want in sorted(checks.items()):
        if key.startswith("min_"):
            name, ok_fn, op = key[4:], (lambda have, w: have >= w), ">="
        elif key.startswith("max_"):
            name, ok_fn, op = key[4:], (lambda have, w: have <= w), "<="
        elif key.startswith("has_"):
            name, ok_fn, op = key[4:], (lambda have, w: have >= w), ">="
        else:
            continue
        have = stats.get(name)
        ok = have is not None and ok_fn(have, want)
        out.append({"check": f"{name} {op} {want}", "value": have, "pass": bool(ok)})
    return out


def validate(obj, lod1_tris, budget_class, stats=None, checks=None):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    tris = sum(len(f.verts) - 2 for f in bm.faces)
    degenerate = sum(1 for f in bm.faces if f.calc_area() < 1e-7)
    loose = sum(1 for v in bm.verts if not v.link_faces)
    open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
    ngons = sum(1 for f in bm.faces if len(f.verts) > 3)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    bm.free()
    size_b = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
    rx, ry, rz = size_to_roblox(size_b)
    pivot_err = max(abs((max(xs) + min(xs)) / 2), abs((max(ys) + min(ys)) / 2), abs(min(zs)))

    uv_ok, uv_out, bad_swatch = True, 0, 0
    used = set()
    if len(me.uv_layers) != 1:
        uv_ok = False
    else:
        uvs = np.empty(len(me.loops) * 2, dtype=np.float32)
        me.uv_layers[0].data.foreach_get("uv", uvs)
        uvs = uvs.reshape(-1, 2)
        uv_out = int(np.sum((uvs < 0) | (uvs > 1)))
        for u, v in np.unique(np.round(uvs, 4), axis=0):
            name = palette.swatch_at_uv(float(u), float(v))
            if name is None:
                bad_swatch += 1
            else:
                used.add(name)
    mats = [s.material.name for s in obj.material_slots if s.material]

    budget = budget_for(budget_class)
    limit = BUDGETS["roblox_max_tris"]
    checks_out = [
        {"check": f"lod0 tris <= budget {budget}", "value": tris, "pass": tris <= budget},
        {"check": f"lod0 tris <= Roblox per-mesh limit {limit}", "value": tris, "pass": tris <= limit},
        {"check": f"lod1 tris < lod0", "value": lod1_tris, "pass": lod1_tris < tris},
        {"check": "max dimension <= 2048 studs", "value": round(max(rx, ry, rz), 3),
         "pass": max(rx, ry, rz) <= BUDGETS["roblox_max_size_studs"]},
        {"check": "pivot at base centre (err <= 0.01)", "value": round(pivot_err, 4), "pass": pivot_err <= 0.01},
        {"check": "no degenerate faces", "value": degenerate, "pass": degenerate == 0},
        {"check": "no loose vertices", "value": loose, "pass": loose == 0},
        {"check": "closed shells (no open edges)", "value": open_edges, "pass": open_edges == 0},
        {"check": "triangulated (no n-gons)", "value": ngons, "pass": ngons == 0},
        {"check": "exactly one UV map, all UVs in 0..1", "value": uv_out, "pass": uv_ok and uv_out == 0},
        {"check": "UVs only sample palette swatches", "value": bad_swatch, "pass": bad_swatch == 0},
        {"check": f"materials <= {BUDGETS['max_materials']}", "value": len(mats),
         "pass": 1 <= len(mats) <= BUDGETS["max_materials"]},
    ]
    checks_out += _structural(stats or {}, checks or {})
    return {
        "asset_id": obj.get("forge_asset_id", obj.name),
        "budget_class": budget_class,
        "triangles": {"lod0": tris, "lod1": lod1_tris, "budget_lod0": budget},
        "size_studs": {"x": round(rx, 3), "y": round(ry, 3), "z": round(rz, 3)},
        "materials": mats,
        "palette_swatches_used": sorted(used),
        "stats": stats or {},
        "checks": checks_out,
        "pass": all(c["pass"] for c in checks_out),
    }


# ------------------------------------------------------------------ variation between variants

def silhouette_masks(obj, cell=0.5):
    """Front (XZ) and side (YZ) occupancy grids in absolute studs, aligned at base centre."""
    me = obj.data
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    co = np.empty(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    tri = np.empty(n * 3, dtype=np.int64)
    me.loop_triangles.foreach_get("vertices", tri)
    t = co[tri.reshape(-1, 3)]  # (n,3,3)
    rng = np.random.default_rng(0)
    masks = []
    for ax in ((0, 2), (1, 2)):
        p = t[:, :, ax]  # (n,3,2)
        area = 0.5 * np.abs((p[:, 1, 0] - p[:, 0, 0]) * (p[:, 2, 1] - p[:, 0, 1]) -
                            (p[:, 2, 0] - p[:, 0, 0]) * (p[:, 1, 1] - p[:, 0, 1]))
        k = np.clip(np.ceil(area / (cell * cell) * 6).astype(int), 3, 400)
        idx = np.repeat(np.arange(n), k)
        r1 = np.sqrt(rng.random(idx.size))
        r2 = rng.random(idx.size)
        a = (1 - r1)[:, None]
        b = (r1 * (1 - r2))[:, None]
        c = (r1 * r2)[:, None]
        pts = a * p[idx, 0] + b * p[idx, 1] + c * p[idx, 2]
        pts = np.concatenate([pts, p.reshape(-1, 2)])
        gx = np.floor(pts[:, 0] / cell).astype(int)
        gz = np.floor(pts[:, 1] / cell).astype(int)
        masks.append(set(zip(gx.tolist(), gz.tolist())))
    return masks


def silhouette_diff(ma, mb):
    """1 - IoU averaged over the front and side projections."""
    out = []
    for a, b in zip(ma, mb):
        u = len(a | b)
        out.append(1.0 - (len(a & b) / u if u else 1.0))
    return sum(out) / len(out)


def variation_report(masks_by_id):
    ids = sorted(masks_by_id)
    pairs = []
    for i in range(len(ids)):
        for j in range(i + 1, len(ids)):
            pairs.append((ids[i], ids[j], silhouette_diff(masks_by_id[ids[i]], masks_by_id[ids[j]])))
    if not pairs:
        return {"min_pair_diff": None, "mean_pair_diff": None, "pass": True, "closest_pair": None}
    lo = min(pairs, key=lambda x: x[2])
    thr = BUDGETS["min_silhouette_diff"]
    return {
        "min_pair_diff": round(lo[2], 4),
        "mean_pair_diff": round(sum(p[2] for p in pairs) / len(pairs), 4),
        "closest_pair": [lo[0], lo[1]],
        "threshold": thr,
        "pass": lo[2] >= thr,
    }


def write_json(data, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return path


__all__ = ["validate", "budget_for", "silhouette_masks", "silhouette_diff", "variation_report", "write_json",
           "BUDGETS", "math"]
