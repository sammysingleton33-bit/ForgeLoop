"""Character-kit build orchestration (FL-0135): piece records, measured budgets, rig.json, FBX export, validation and the FBX
round-trip check. Style-independent: it takes a Registry (generators/_charkit_style.py) plus the rig definition.
"""

import hashlib
import json
import math
import re
import shutil
from pathlib import Path

from . import ckit

NAME_RE = re.compile(r"^[a-z][a-z0-9_]*$")
CITIZEN_TRIS = 1000  # D-057 (11): per assembled citizen (body <= 900, tool <= 150)
RULER_TRIS = 1500  # soldiers and rulers are few: the amended budget allows 1,500 if a render shows the need
TOOL_TRIS = 150
BODY_TRIS = 900
MAX_PIECES = 16  # contract: pieces per assembled rig
ROBLOX_MAX_TRIS = 20000
BIG_RIGS = ("soldier", "soldier_knight", "soldier_archer", "governor")
# the runtime contract (art/char_kit/rig_to_luau.py) knows these slots; the kit's finer slots keep their name in `kit_slot`
SLOT_MAP = {"hatband": "hat", "crest": "hat", "toolband": "tool", "extra": "acc", "shield": "acc", "skirt": "acc"}
TOOL_JOINTS = ("Tool", "TorsoTool")  # what counts as "the hand tool or sack" against the <= 150 budget (as rig_to_luau.py)


def tri_count(m):
    return m.copy().triangulate().tris if m.cc is None else m.tris


def canon_hash(pieces):
    """Order-independent hash of every piece's triangles + colours (stable across bmesh op orderings)."""
    h = hashlib.sha1()
    for name in sorted(pieces):
        m = pieces[name].m
        t = m.copy().triangulate()
        rows = []
        for f, c in zip(t.f, t.c):
            pts = sorted("%.3f,%.3f,%.3f" % t.v[i] for i in f)
            rows.append("|".join(pts) + "#%.2f,%.2f,%.2f" % tuple(c))
        rows.sort()
        h.update(name.encode())
        h.update("\n".join(rows).encode())
    return h.hexdigest()[:16]


def piece_records(R, hand, rig=None):
    """name -> dict with the contract fields (bbox in rig frame, tris, joint, tint, slot, tags)."""
    out = {}
    for name, p in R.pieces.items():
        m = p.m.copy().triangulate()
        (x0, y0, z0), (x1, y1, z1) = m.bounds()
        out[name] = {
            "joint": p.joint,
            "weld_to": p.joint if p.weld else None,  # the contract: null = the base piece of its joint, else the joint it is welded to
            "bbox_center": [round((x0 + x1) / 2, 4), round((y0 + y1) / 2, 4), round((z0 + z1) / 2, 4)],
            "size": [round(x1 - x0, 4), round(y1 - y0, 4), round(z1 - z0, 4)],
            "tris": m.tris,
            "verts": len(m.v),
            "tint": p.tint,
            "slot": SLOT_MAP.get(p.slot, p.slot),
            "tags": sorted(set(p.tags)),
        }
        if p.slot in SLOT_MAP:
            out[name]["kit_slot"] = p.slot
        if p.tint == "kingdom" and rig is not None:
            out[name]["tint_factor"] = rig.KIT_TINT.get(name[:-2] if name.endswith(("_l", "_r")) else name, 0.85)
        if "width" in p.info:
            out[name]["width"] = p.info["width"]
    return out


def rig_measure(R, rig, jobs=None, kingdoms=None):
    """Measured triangles / pieces / draw calls per assembled job rig: default look, worst case over all looks and kingdoms."""
    jobs = jobs or list(rig.ASSEMBLIES)
    kingdoms = kingdoms or rig.KINGDOMS
    tris = {n: tri_count(p.m) for n, p in R.pieces.items()}
    table = {}
    for job in jobs:
        a = rig.ASSEMBLIES[job]
        default = rig.names_for(job)
        looks = _all_looks()
        worst, worst_names, pmax, tool_max, body_max = 0, default, 0, 0, 0
        for kd in kingdoms:
            for lk in looks:
                names = rig.names_for(job, lk, kd)
                t = sum(tris[n] for n in names)
                tl = sum(tris[n] for n in names if R.pieces[n].joint in TOOL_JOINTS)
                pmax = max(pmax, len(names))
                tool_max, body_max = max(tool_max, tl), max(body_max, t - tl)
                if t > worst:
                    worst, worst_names = t, names
        tool_t = tool_max
        budget = RULER_TRIS if job in BIG_RIGS else CITIZEN_TRIS
        table[job] = {
            "pieces_default": len(default),
            "tris_default": sum(tris[n] for n in default),
            "pieces_max": pmax,
            "tris_max": worst,
            "tool_tris": tool_t,
            "body_tris": body_max,
            "budget": budget,
            "draw_calls_est": len(worst_names),  # one MeshPart per piece; identical MeshContent instances into fewer
            "texture_bytes": 0,
            "pass": worst <= budget and pmax <= MAX_PIECES and (job in BIG_RIGS or (body_max <= BODY_TRIS and tool_max <= TOOL_TRIS)),
            "worst_pieces": worst_names,
        }
    return table


def _all_looks():
    from . import manifest

    return manifest.kit_looks()  # every look of G13.2: the same set the manifest check measures


def build_objects(R, collection=None):
    """Mesh objects for every piece (rig frame, origin at the bbox centre), one shared vertex-colour material."""
    import bpy

    mat = ckit.vertex_color_material()
    objs = []
    for name in sorted(R.pieces):
        p = R.pieces[name]
        obj, lo, hi = ckit.to_object(name, p.m, ao=R.S.ao, facet=R.S.facet, seed=_seed(name), collection=collection)
        obj.data.materials.append(mat)
        obj["forge_piece"] = name
        objs.append(obj)
    bpy.context.view_layer.update()
    return objs


def _seed(name):
    return int(hashlib.md5(name.encode()).hexdigest()[:6], 16)


def validate_objects(objs):
    """Per-piece geometry checks (Roblox specs A1/A2): triangulated, watertight, no degenerate faces, vertex colours."""
    import bmesh

    rows, ok = {}, True
    for o in objs:
        me = o.data
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.normal_update()
        tris = sum(len(f.verts) - 2 for f in bm.faces)
        ngons = sum(1 for f in bm.faces if len(f.verts) > 3)
        degenerate = sum(1 for f in bm.faces if f.calc_area() < 1e-7)
        loose = sum(1 for v in bm.verts if not v.link_faces)
        open_edges = sum(1 for e in bm.edges if len(e.link_faces) != 2)
        nonman = sum(1 for e in bm.edges if len(e.link_faces) > 2)
        volume = bm.calc_volume(signed=True)
        bm.free()
        dims = [abs(o.dimensions[i]) for i in range(3)]
        row = {
            "tris": tris, "ngons": ngons, "degenerate": degenerate, "loose": loose, "open_edges": open_edges,
            "colour_layers": len(me.color_attributes), "materials": len(me.materials), "size": [round(d, 3) for d in dims],
            "name_ok": bool(NAME_RE.match(o.name)), "volume": round(volume, 4),
        }
        row["pass"] = (tris <= ROBLOX_MAX_TRIS and ngons == 0 and degenerate == 0 and loose == 0 and row["colour_layers"] == 1
                       and row["materials"] == 1 and row["name_ok"] and max(dims) <= 2048 and min(dims) > 0.01)
        row["watertight"] = open_edges == 0 and nonman == 0
        if row["watertight"] and volume <= 0:  # inside-out shell: Roblox would cull the whole piece
            row["pass"] = False
        rows[o.name] = row
        ok = ok and row["pass"]
    return rows, ok


def kit_dependency_hash(R):
    return canon_hash(R.pieces)


def rig_json(R, rig, style_name, hand, extra=None):
    """The contract document (schema_version 1, validated by games/game-001/art/char_kit/rig_to_luau.py) plus additive sections
    (tints for the Blender-side renders, budgets, the measured table)."""
    joints = {}
    for k, v in rig.JOINTS.items():
        pos = v["pos"] if v["pos"] is not None else [round(hand[0], 4), round(hand[1], 4), round(hand[2], 4)]
        joints[k] = {"parent": v["parent"], "pos": pos}
    pieces = piece_records(R, hand, rig)
    for pid, e in rig.EMPTY_PIECES.items():  # variants that mean "none": no mesh, no FBX object
        pieces[pid] = {"joint": e["joint"], "empty": True, "tint": e["tint"], "slot": e["slot"], "tags": list(e["tags"])}
    assemblies = {job: {k: (list(v) if isinstance(v, list) else v) for k, v in a.items()} for job, a in rig.ASSEMBLIES.items()}
    doc = {
        "schema_version": 1,
        "unit": "stud",
        "generator": "blender/generators/char_kit.py",
        "style": style_name,
        "root_height": 3.2,
        "frame": "Roblox rig axes: +X right, +Y up, -Z front, feet at y = 0, centred on x = 0, z = 0 (studs). Blender authoring: "
                 "(bx, by, bz) = (x, -z, y); FBX exported Y up / -Z forward, 1 unit = 1 stud.",
        "joints": joints,
        "pieces": pieces,
        "assemblies": assemblies,
        "looks": {
            "rule": "Templates in `assemblies` are resolved exactly like Kit/CharacterMesh.luau (blender/lib/ckit_resolve.py is the "
                    "Python port): %look.<axis>% picks one of the numbered variants (prefix + digits + suffix, numeric order) by the look "
                    "(skin / hair / hairColor / outfit follow the field and spill over extra variants; face / boots / acc mix the look), "
                    "%kingdom% is crimson | azure | emerald | gold. Variants: head_01..06 faces, hair_01..10 (10 = a kingdom hood) and "
                    "hair_beard, torso_01..06 cuts, boot_01..03_l/_r, acc_01 (none) / acc_02 (headband).",
            "kingdoms": list(rig.KINGDOMS),
        },
        "tints": {
            "rule": "MeshPart.Color = skin | hair | shade(kingdomColor, tint_factor) | cloth | white (fixed); baked vertex colours are "
                    "multiplied by it. Unverified in Studio. The Blender renders use the values below, which mirror Kit/Character.luau.",
            "skin": [[242, 201, 160], [255, 222, 196], [210, 156, 112], [162, 108, 70], [110, 70, 44], [78, 50, 34]],
            "hair": [[92, 58, 32], [36, 28, 24], [150, 94, 48], [222, 178, 92], [178, 74, 34], [206, 204, 198], [62, 42, 30],
                     [242, 224, 166]],
            "kingdom": {"crimson": [190, 40, 50], "azure": [40, 110, 210], "gold": [235, 185, 16], "emerald": [35, 128, 95]},
            "tint_shift": rig.TINT_SHIFT,
            "tint_shift_rule": "soldier sleeves only: factor + tint_shift[(look.hairColor + look.skin - 2) % 8], clamped to 0.5..1 "
                               "(an approximation of the runtime's per-individual shift)",
            "cloth_panels": {k: [list(c) for c in v] for k, v in rig.CLOTH_PANELS.items()},
            "cloth_legs": {k: [list(c) for c in v] for k, v in rig.CLOTH_LEGS.items()},
            "cloth_rule": "cloth piece colour = (slot 'leg' ? cloth_legs : cloth_panels)[job or 'folk'][(look.hairColor - 1) % 3] x dye[look.hairColor - 1]",
            "dye": rig.DYE,
        },
    }
    if extra:
        doc.update(extra)
    return doc


def write_json(doc, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=1, sort_keys=False) + "\n")
    return path


def roundtrip_fbx(fbx_path, doc, tol=0.02):
    """Import the exported FBX into a fresh scene and compare every object's bbox with rig.json (Blender-side evidence only)."""
    import bpy
    from mathutils import Vector

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(fbx_path), axis_forward="-Z", axis_up="Y", global_scale=1.0)
    bad, n = [], 0
    for o in bpy.context.scene.objects:
        if o.type != "MESH":
            continue
        n += 1
        pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
        mn = [min(p[i] for p in pts) for i in range(3)]
        mx = [max(p[i] for p in pts) for i in range(3)]
        # Blender (bx, by, bz) -> rig (bx, bz, -by)
        c = [(mn[0] + mx[0]) / 2, (mn[2] + mx[2]) / 2, -(mn[1] + mx[1]) / 2]
        sz = [mx[0] - mn[0], mx[2] - mn[2], mx[1] - mn[1]]
        rec = doc["pieces"].get(o.name)
        if rec is None:
            bad.append((o.name, "not in rig.json"))
            continue
        dc = max(abs(a - b) for a, b in zip(c, rec["bbox_center"]))
        ds = max(abs(a - b) for a, b in zip(sz, rec["size"]))
        if dc > tol or ds > tol:
            bad.append((o.name, f"centre off by {dc:.3f}, size off by {ds:.3f}"))
        if len(o.data.color_attributes) < 1:
            bad.append((o.name, "no vertex colours after import"))
    missing = sorted({k for k, v in doc["pieces"].items() if not v.get("empty")} - {o.name for o in bpy.context.scene.objects if o.type == "MESH"})
    return {"objects": n, "mismatches": bad, "missing": missing, "pass": not bad and not missing}


# ------------------------------------------------------------------ generator driver (build.py KIT branch)

def render_preview(fbx, rig_path, out_jpg, samples=16, size=(1600, 440)):
    """Manifest preview: every identity side by side, assembled from the SHIPPED fbx + rig.json (Cycles, <= 250 KB JPEG)."""
    from PIL import Image

    from . import ckit_rigload, ckit_scene, ckit_view
    from . import rig as scene_rig

    sc = ckit_view.stage(size[0], size[1], samples)
    kit = ckit_rigload.Kit(fbx, rig_path)
    n = len(ckit_rigload.JOBS)
    for i, job in enumerate(ckit_rigload.JOBS):
        kit.spawn(job, ckit_rigload.job_look(i), "crimson", ((n - 1) / 2 - i) * 6.2, 0, 0, tag=f"{job}_")
    cam = scene_rig.add_camera(sc, 70)
    ckit_scene.gameplay(cam, (0, 3.3, 0), 15.0, 6.0, fov=70)
    tmp = Path(out_jpg).with_suffix(".png")
    scene_rig.render(sc, tmp)
    im = Image.open(tmp).convert("RGB")
    for q in (88, 80, 72, 64, 56, 48):
        im.save(out_jpg, quality=q, optimize=True)
        if Path(out_jpg).stat().st_size <= 250 * 1024:
            break
    tmp.unlink()
    return Path(out_jpg).stat().st_size


def run_generator(gen, args, expect=None):
    """Build the kit with generator module `gen` (provides NAME, VERSION, STYLE, registry()), validate, export, write rig.json
    and the manifest fragment. With `expect` (a committed fragment): rebuild only and compare hashes (check.sh --verify)."""
    import time

    import bpy

    from . import manifest, validate

    t0 = time.time()
    from . import rig as scene_rig

    scene_rig.reset_scene()
    R, rig, hand = gen.registry()
    objs = build_objects(R)
    rows, geom_ok = validate_objects(objs)
    table = rig_measure(R, rig)
    ghash = canon_hash(R.pieces)
    big = [j for j in table if j in BIG_RIGS]
    citizen_max = max(t["tris_max"] for j, t in table.items() if j not in BIG_RIGS)
    ruler_max = max(table[j]["tris_max"] for j in big)
    total_tris = sum(r["tris"] for r in rows.values())
    rig_ok = all(t["pass"] for t in table.values())
    ok = geom_ok and rig_ok
    entry_id = f"{gen.NAME}_01"
    mn = [min(p.m.bounds()[0][i] for n, p in R.pieces.items() if n in table["farmer"]["worst_pieces"]) for i in range(3)]
    mx = [max(p.m.bounds()[1][i] for n, p in R.pieces.items() if n in table["farmer"]["worst_pieces"]) for i in range(3)]
    dims = {"x": round(mx[0] - mn[0], 3), "y": round(mx[1] - mn[1], 3), "z": round(mx[2] - mn[2], 3)}
    doc = rig_json(R, rig, gen.STYLE, hand, extra={
        "budget": {"citizen_tris": CITIZEN_TRIS, "ruler_tris": RULER_TRIS, "tool_tris": TOOL_TRIS, "body_tris": BODY_TRIS,
                   "max_pieces": MAX_PIECES, "texture_bytes": 0, "materials": 1},
        "measured": {j: {k: v for k, v in t.items() if k != "worst_pieces"} for j, t in table.items()},
        "geometry_hash": ghash,
    })
    entry = {
        "id": entry_id, "generator": gen.NAME, "generator_version": gen.VERSION, "category": gen.CATEGORY, "kingdom": None,
        "params": {"style": gen.STYLE, "pieces": len(R.pieces), "jobs": sorted(rig.ASSEMBLIES)},
        "seed": int(args.seed), "budget_class": gen.BUDGET, "dimensions_studs": dims,
        "triangles": {"lod0": citizen_max, "lod1": 12, "budget_lod0": CITIZEN_TRIS},
        "material": "M_charkit_vc", "texture": "none (vertex colours, 0 bytes of texture memory)",
        "collision": {"fidelity": "Box", "boxes": []}, "double_sided": False, "render_fidelity": "Automatic",
        "files": {"mesh": "exports/citizen_kit.fbx", "validation": "exports/char_kit.validation.json",
                  "rig": "games/game-001/art/char_kit/rig.json", "mesh_committed": "games/game-001/art/char_kit/citizen_kit.fbx"},
        "preview": "previews/char_kit.jpg",
        "sockets": {k: v["pos"] for k, v in doc["joints"].items()},
        "validation_pass": bool(ok), "geometry_hash": ghash,
        "review": manifest.review_for(gen.NAME, entry_id, ghash),
        "license": getattr(gen, "LICENSE", "project-original"),
        "kit": {"style": gen.STYLE, "pieces": len(R.pieces), "total_piece_tris": total_tris, "max_citizen_tris": citizen_max,
                "max_ruler_tris": ruler_max, "jobs": {j: {"tris_max": t["tris_max"], "pieces_max": t["pieces_max"]} for j, t in table.items()}},
    }
    for k, v in getattr(gen, "PROVENANCE", {}).items():
        entry[k] = v
    print(f"[{gen.NAME}] {len(R.pieces)} pieces, {total_tris} tris in the FBX; max citizen rig {citizen_max}/{CITIZEN_TRIS}, "
          f"max soldier/governor {ruler_max}/{RULER_TRIS}; geometry {'PASS' if geom_ok else 'FAIL'}; hash {ghash}", flush=True)
    for j, t in table.items():
        print(f"[{gen.NAME}]   {j:14s} tris {t['tris_default']:5d} (max {t['tris_max']:5d}, tool {t['tool_tris']:4d}) pieces {t['pieces_default']:2d} "
              f"(max {t['pieces_max']:2d}) {'PASS' if t['pass'] else 'FAIL'}", flush=True)
    if expect is not None:
        want = {e["id"]: (e["geometry_hash"], e["triangles"]["lod0"]) for e in expect["assets"]}
        got = {entry_id: (ghash, citizen_max)}
        good = ok and got == want
        if got != want:
            print(f"[{gen.NAME}] VERIFY MISMATCH committed {want} rebuilt {got}", flush=True)
        print(f"[{gen.NAME}] verify {'PASS' if good else 'FAIL'} (1 asset)", flush=True)
        return good
    out = Path(args.out)
    export_fbx = out / "citizen_kit.fbx"
    ckit.export_fbx(objs, export_fbx)
    doc["fbx_bytes"] = export_fbx.stat().st_size
    rt = roundtrip_fbx(export_fbx, doc)
    print(f"[{gen.NAME}] FBX {export_fbx.stat().st_size} bytes; round-trip {rt['objects']} objects, mismatches {len(rt['mismatches'])}, "
          f"missing {len(rt['missing'])} -> {'PASS' if rt['pass'] else 'FAIL'}", flush=True)
    ok = ok and rt["pass"]
    entry["validation_pass"] = bool(ok)
    rig_path = Path(__file__).resolve().parents[2] / "games/game-001/art/char_kit/rig.json"
    write_json(doc, rig_path)
    write_json(doc, out / "rig.json")
    shipped = rig_path.parent / "citizen_kit.fbx"  # the import-ready FBX is small (~0.5 MB); committed next to rig.json for worker K
    shutil.copyfile(export_fbx, shipped)
    write_json({"asset_id": entry_id, "pieces": rows, "measured": table, "roundtrip": rt, "pass": bool(ok)}, out / "char_kit.validation.json")
    if not args.no_manifest:
        manifest.write_fragment(gen.NAME, [entry], {"min_pair_diff": None, "pass": True}, {"seed": args.seed, "variants": 1})
        manifest.merge()
    if not args.no_render:
        size = render_preview(shipped, rig_path, Path(__file__).resolve().parents[1] / "previews" / "char_kit.jpg")
        print(f"[{gen.NAME}] preview previews/char_kit.jpg {size} bytes", flush=True)
    print(f"[{gen.NAME}] done in {time.time() - t0:.0f}s", flush=True)
    return ok
