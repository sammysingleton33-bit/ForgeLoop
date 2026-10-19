"""Environment-kit build orchestration (FL-0136 phase 2): prop records, fit figures against the part-built stand-ins, measured budgets,
env.json, FBX export, validation and the FBX round-trip check. The kit is ONE FBX with one mesh object per asset id.

    ~/forge-bpy/bin/python blender/build.py --generator env_kit [--no-render] [--no-manifest]

Writes (committed): games/game-001/art/env_kit/env_kit.fbx, games/game-001/art/env_kit/env.json, blender/manifest.d/env_kit.json
(+ blender/previews/env_kit.jpg unless --no-render). With `expect` (check.sh --verify): rebuild and compare the geometry hash only.
Frame: Roblox axes, studs, base on y = 0, +X right, +Y up, -Z front (see games/game-001/art/reviews/env-mesh.md "Phase 2").
"""

import hashlib
import json
import math
import shutil
from pathlib import Path

from . import ckit, ckit_kit, envkit_standin

REPO = Path(__file__).resolve().parents[2]
OUT_DIR = REPO / "games/game-001/art/env_kit"
FBX_NAME, ENV_NAME = "env_kit.fbx", "env.json"
FIT_RADIUS, FIT_HEIGHT = 0.15, 0.25  # contract: footprint radius +-15 %, height +-25 % of the stand-in unless the id's role needs more
SINK_MAX = 0.6  # a foot, root flare or rock may sit this far below the ground plane (y = 0)


def _seed(name):
    return int(hashlib.md5(name.encode()).hexdigest()[:6], 16)


def build_objects(reg, collection=None):
    """Mesh objects for every prop (Roblox axes, origin at the bounding-box centre), one shared vertex-colour material."""
    import bpy

    from generators import _envkit_style as S

    mat = ckit.vertex_color_material("M_envkit_vc")
    objs = []
    for pid in reg:
        obj, lo, hi = ckit.to_object(pid, reg[pid].m, ao=S.AO, facet=S.FACET, seed=_seed(pid), collection=collection)
        obj.data.materials.append(mat)
        obj["forge_prop"] = pid
        objs.append(obj)
    bpy.context.view_layer.update()
    return objs


def canon_hash(reg):
    return ckit_kit.canon_hash(reg)  # Prop.m is what the helper reads (sorted by id, order-independent, rounded to 1 mm)


def prop_record(p, standins):
    """The contract fields plus the fit figures for one prop."""
    m = p.m.copy().triangulate()
    (x0, y0, z0), (x1, y1, z1) = m.bounds()
    size = [x1 - x0, y1 - y0, z1 - z0]
    radius = max(math.hypot(v[0], v[2]) for v in m.v)
    corner = math.hypot(max(abs(x0), abs(x1)), max(abs(z0), abs(z1)))
    s = standins.get(p.id)
    rec = {
        "family": p.family,
        "bbox_center": [round((x0 + x1) / 2, 4), round((y0 + y1) / 2, 4), round((z0 + z1) / 2, 4)],
        "size": [round(v, 4) for v in size],
        "tris": m.tris,
        "verts": len(m.v),
        "tint": "fixed",
        "standin_size": s["size"] if s else None,
        "node": bool(p.node),
        "placed": bool(s["placed"]) if s else False,
        "base_y": round(y0, 3),
        "radius_xz": round(radius, 3),
        "reach_bbox": round(corner, 3),
    }
    if s:
        r_m, r_s = (size[0] + size[2]) / 4, (s["size"][0] + s["size"][2]) / 4
        rec["standin_reach"] = s["reach"]
        rec["standin_parts"] = s["parts"]
        rec["fit"] = {"radius": round(r_m, 2), "standin_radius": round(r_s, 2), "radius_ratio": round(r_m / r_s, 3),
                      "height": round(y1, 2), "standin_height": s["size"][1], "height_ratio": round(y1 / s["size"][1], 3)}
        rec["count_world"] = {"density_1": s["count_full"], "shipped": s["count_shipped"]}
    for k, v in p.info.items():
        if k in ("archetype", "shape", "kind", "stage", "rows", "along", "tiers", "lobes", "colours", "stones"):
            rec.setdefault("variant_info", {})[k] = v
    if p.info.get("fit_note"):
        rec["fit_note"] = p.info["fit_note"]
    return rec


def fit_errors(records, notes=None):
    """Fit figures outside the contract's tolerances. A prop with a `fit_note` (the reason) is reported but allowed."""
    out = []
    for pid, r in records.items():
        f = r.get("fit")
        if not f:
            continue
        if abs(f["radius_ratio"] - 1) > FIT_RADIUS and not r.get("fit_note"):
            out.append(f"{pid}: footprint radius {f['radius']} vs stand-in {f['standin_radius']} ({f['radius_ratio'] - 1:+.0%})")
        if abs(f["height_ratio"] - 1) > FIT_HEIGHT and not r.get("fit_note"):
            out.append(f"{pid}: height {f['height']} vs stand-in {f['standin_height']} ({f['height_ratio'] - 1:+.0%})")
    return out


def measured_table(records, family_budget):
    fam = {}
    for pid, r in records.items():
        e = fam.setdefault(r["family"], {"props": 0, "tris_min": 10 ** 9, "tris_max": 0, "tris_total": 0, "budget": list(family_budget[r["family"]])})
        e["props"] += 1
        e["tris_min"] = min(e["tris_min"], r["tris"])
        e["tris_max"] = max(e["tris_max"], r["tris"])
        e["tris_total"] += r["tris"]
    return fam


def env_doc(gen, reg, records, ghash):
    return {
        "schema_version": 1,
        "unit": "stud",
        "generator": "blender/generators/env_kit.py",
        "style": gen.STYLE,
        "frame": "Roblox axes: +X right, +Y up, -Z front, studs. Every prop stands on y = 0 (the ground plane = the Model pivot plane) and is centred on x = z = 0 as the "
                 "part-built stand-in is (a tree: its trunk); `base_y` <= 0 is how far a foot, root flare or rock sinks below it. `bbox_center` and `size` describe the "
                 "mesh's bounding box RELATIVE to that pivot (the FBX object's origin sits at the box centre, as in the citizen kit). Blender authoring: "
                 "(bx, by, bz) = (x, -z, y); the FBX is exported Y up / -Z forward, 1 unit = 1 stud.",
        "radius_rule": "`radius_xz` is the true horizontal reach (farthest vertex from the pivot axis); `reach_bbox` is what a box-based check measures for a MeshPart "
                       "(the farthest corner of the bounding box around the pivot): up to 1.41x the radius of a round prop. `standin_reach` is the figure "
                       "tests/world/PlotClearance measures for the part-built prop (WorldPlan.CLEAR.radius is that rounded up).",
        "tints": "every prop is `fixed`: MeshPart.Color stays white and the baked vertex colours are the look (nothing is kingdom-tinted). Unverified in Studio.",
        "budget": {k: {"min": v[0], "max": v[1]} for k, v in gen.FAMILY_BUDGET.items()} | {"mesh_max": ckit_kit.ROBLOX_MAX_TRIS, "materials": 1, "texture_bytes": 0},
        "measured": measured_table(records, gen.FAMILY_BUDGET),
        "geometry_hash": ghash,
        "standins": {"kit_version": envkit_standin.load().get("kit_version"), "source": "blender/lib/envkit_standins.json (from blender/scripts/lune/EnvInventory.spec.luau)"},
        "props": records,
    }


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def roundtrip_fbx(fbx_path, doc, tol=0.02):
    """Import the exported FBX into a fresh scene and compare every object's bbox with env.json (Blender-side evidence only)."""
    shim = {"pieces": {k: {"bbox_center": v["bbox_center"], "size": v["size"]} for k, v in doc["props"].items()}}
    return ckit_kit.roundtrip_fbx(fbx_path, shim, tol)


def run_generator(gen, args, expect=None):
    """Build the kit with generator module `gen` (provides NAME, VERSION, STYLE, FAMILY_BUDGET, registry()), validate, export, write env.json and the
    manifest fragment. With `expect` (a committed fragment): rebuild only and compare the geometry hash."""
    import time

    from . import manifest
    from . import rig as scene_rig

    t0 = time.time()
    scene_rig.reset_scene()
    reg = gen.registry(args.seed if args.seed is not None else gen.SEED)
    standins = envkit_standin.load()["standins"]
    objs = build_objects(reg)
    rows, geom_ok = ckit_kit.validate_objects(objs)
    records = {pid: prop_record(p, standins) for pid, p in reg.items()}
    ghash = canon_hash(reg)
    budget_errs = []
    for pid, r in records.items():
        lo, hi = gen.FAMILY_BUDGET[r["family"]]
        if not lo <= r["tris"] <= hi:
            budget_errs.append(f"{pid}: {r['tris']} triangles outside the {r['family']} budget {lo}..{hi}")
        if r["base_y"] < -SINK_MAX:
            budget_errs.append(f"{pid}: sinks {r['base_y']} below the ground plane (max {SINK_MAX})")
        (x0, y0, z0), (x1, y1, z1) = [(r["bbox_center"][i] - r["size"][i] / 2) for i in range(3)], [(r["bbox_center"][i] + r["size"][i] / 2) for i in range(3)]
        if not (x0 <= 0.0 <= x1 and z0 <= 0.0 <= z1):
            budget_errs.append(f"{pid}: the pivot (0, 0) is outside the footprint box")
    fit_errs = fit_errors(records)
    ok = geom_ok and not budget_errs
    max_tris = max(r["tris"] for r in records.values())
    total = sum(r["tris"] for r in records.values())
    print(f"[{gen.NAME}] {len(reg)} props, {total} tris in the FBX (max one mesh {max_tris}); geometry {'PASS' if geom_ok else 'FAIL'}; hash {ghash}", flush=True)
    for fam, e in measured_table(records, gen.FAMILY_BUDGET).items():
        print(f"[{gen.NAME}]   {fam:7s} {e['props']:3d} props  tris {e['tris_min']:5d}..{e['tris_max']:5d} (budget {e['budget'][0]}..{e['budget'][1]})", flush=True)
    for e in budget_errs + fit_errs:
        print(f"[{gen.NAME}] {'BUDGET' if e in budget_errs else 'FIT'}: {e}", flush=True)
    bad_rows = [pid for pid, r in rows.items() if not r["pass"]]
    for pid in bad_rows:
        print(f"[{gen.NAME}] geometry FAIL {pid}: {rows[pid]}", flush=True)
    if expect is not None:
        want = {e["id"]: (e["geometry_hash"], e["triangles"]["lod0"]) for e in expect["assets"]}
        got = {f"{gen.NAME}_01": (ghash, max_tris)}
        good = ok and got == want
        if got != want:
            print(f"[{gen.NAME}] VERIFY MISMATCH committed {want} rebuilt {got}", flush=True)
        print(f"[{gen.NAME}] verify {'PASS' if good else 'FAIL'} (1 asset)", flush=True)
        return good
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    export_fbx = out / FBX_NAME
    ckit.export_fbx(objs, export_fbx)
    doc = env_doc(gen, reg, records, ghash)
    doc["fbx_bytes"] = export_fbx.stat().st_size
    doc["fbx_sha256"] = sha256(export_fbx)
    rt = roundtrip_fbx(export_fbx, doc)
    print(f"[{gen.NAME}] FBX {export_fbx.stat().st_size} bytes; round-trip {rt['objects']} objects, mismatches {len(rt['mismatches'])}, missing {len(rt['missing'])} -> "
          f"{'PASS' if rt['pass'] else 'FAIL'}", flush=True)
    ok = ok and rt["pass"]
    doc["roundtrip"] = {"objects": rt["objects"], "mismatches": len(rt["mismatches"]), "pass": bool(rt["pass"])}
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    ckit_kit.write_json(doc, OUT_DIR / ENV_NAME)
    ckit_kit.write_json(doc, out / ENV_NAME)
    shutil.copyfile(export_fbx, OUT_DIR / FBX_NAME)
    ckit_kit.write_json({"asset_id": f"{gen.NAME}_01", "props": rows, "measured": doc["measured"], "roundtrip": rt, "budget_errors": budget_errs, "fit_errors": fit_errs,
                         "pass": bool(ok)}, out / f"{gen.NAME}.validation.json")
    dims = {a: round(max(r["size"][i] for r in records.values()), 3) for i, a in enumerate("xyz")}
    entry = {
        "id": f"{gen.NAME}_01", "generator": gen.NAME, "generator_version": gen.VERSION, "category": gen.CATEGORY, "kingdom": None,
        "params": {"style": gen.STYLE, "props": len(reg), "families": sorted({r["family"] for r in records.values()})},
        "seed": int(args.seed), "budget_class": gen.BUDGET, "dimensions_studs": dims,
        "triangles": {"lod0": max_tris, "lod1": min(r["tris"] for r in records.values()), "budget_lod0": max(v[1] for v in gen.FAMILY_BUDGET.values())},
        "material": "M_envkit_vc", "texture": "none (vertex colours, 0 bytes of texture memory)",
        "collision": {"fidelity": "Box", "boxes": []}, "double_sided": False, "render_fidelity": "Automatic",
        "files": {"mesh": f"exports/{FBX_NAME}", "validation": f"exports/{gen.NAME}.validation.json", "env": f"games/game-001/art/env_kit/{ENV_NAME}",
                  "mesh_committed": f"games/game-001/art/env_kit/{FBX_NAME}"},
        "preview": "previews/env_kit.jpg", "sockets": {},
        "validation_pass": bool(ok), "geometry_hash": ghash,
        "review": manifest.review_for(gen.NAME, f"{gen.NAME}_01", ghash),
        "license": getattr(gen, "LICENSE", "project-original"),
        "kit": {"style": gen.STYLE, "props": len(reg), "total_tris": total, "max_mesh_tris": max_tris, "fbx_sha256": doc["fbx_sha256"],
                "families": {f: {k: v for k, v in e.items() if k in ("props", "tris_min", "tris_max", "tris_total")} for f, e in doc["measured"].items()}},
    }
    if not args.no_manifest:
        manifest.write_fragment(gen.NAME, [entry], {"min_pair_diff": None, "pass": True}, {"seed": args.seed, "variants": 1})
        manifest.merge()
    if not args.no_render:
        from . import envkit_scene

        size = envkit_scene.render_preview(OUT_DIR / FBX_NAME, OUT_DIR / ENV_NAME, Path(__file__).resolve().parents[1] / "previews" / "env_kit.jpg")
        print(f"[{gen.NAME}] preview previews/env_kit.jpg {size} bytes", flush=True)
    print(f"[{gen.NAME}] done in {time.time() - t0:.0f}s", flush=True)
    return ok and not fit_errs
