"""FORGE-02 asset build: generate -> validate -> export (FBX) -> render -> contact sheet -> manifest.

Run (cloud, bpy wheel):   ~/forge-bpy/bin/python blender/build.py --generator house_cottage
Run (desktop Blender):    blender -b -P blender/build.py -- --generator house_cottage
Options:
  --generator NAME [NAME ...] | --all     what to build
  --variants N --seed S                   variant count (default: generator's) and seed (default 7)
  --no-render | --quick                   skip previews | low-res fast previews
  --no-export                             skip FBX files (validation still runs)
  --merge-only                            just merge manifest.d/ into manifest.json
  --verify                                rebuild every committed fragment (no render/export/manifest
                                          writes) and fail if any geometry hash or tri count differs
  --list                                  list generators
Exit code 1 if any asset fails validation or the variation check.
"""

import argparse
import hashlib
import math
import importlib
import json
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

GEN_DIR = HERE / "generators"


def parse_args(argv):
    """Arguments after '--' (Blender style) or, without '--', everything after the script."""
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]
    ap = argparse.ArgumentParser(prog="build.py", description=__doc__.split("\n")[0])
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--generator", nargs="+", metavar="NAME")
    g.add_argument("--all", action="store_true")
    g.add_argument("--merge-only", action="store_true")
    g.add_argument("--list", action="store_true")
    g.add_argument("--verify", action="store_true")
    ap.add_argument("--variants", type=int)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--no-render", action="store_true")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--no-manifest", action="store_true", help="do not write manifest.d / manifest.json")
    ap.add_argument("--samples", type=int)
    ap.add_argument("--out", default=str(HERE / "exports"))
    ap.add_argument("--renders", default=str(HERE / "renders"))
    return ap.parse_args(argv)


def list_generators():
    return sorted(p.stem for p in GEN_DIR.glob("*.py") if not p.stem.startswith("_"))


def geometry_hash(obj):
    h = hashlib.sha1()
    for v in obj.data.vertices:
        h.update(("%.3f,%.3f,%.3f;" % tuple(v.co)).encode())
    for p in obj.data.polygons:
        h.update((",".join(map(str, p.vertices)) + ";").encode())
    return h.hexdigest()[:16]


def asset_id_for(gen, i, params):
    if hasattr(gen, "asset_id"):
        return gen.asset_id(i, params)
    return f"{gen.NAME}_{i + 1:02d}"


def build_generator(name, args, expect=None):
    import bpy  # noqa: F401  (import here so --list / tests work without bpy)

    from lib import asset, contact, export, manifest, rig, validate

    gen = importlib.import_module(f"generators.{name}")
    n = args.variants or getattr(gen, "DEFAULT_VARIANTS", 6)
    out = Path(args.out)
    rdir = Path(args.renders) / name
    rdir.mkdir(parents=True, exist_ok=True)
    quick = args.quick
    hero_px = 320 if quick else 600
    samples = args.samples or (12 if quick else 32)

    rig.reset_scene()
    asset.write_palette_png()
    sc = rig.standard_stage(hero_px, hero_px, samples)
    params_list = gen.variants(n, args.seed)
    objs, entries, masks, reports = [], [], {}, {}
    t0 = time.time()
    for i, params in enumerate(params_list):
        aid = asset_id_for(gen, i, params)
        seed = int(params.get("seed", args.seed * 1000 + i))
        b = asset.Builder(aid, seed)
        gen.build(b, params)
        ob = b.finalize()
        lod1 = asset.make_lod1(ob, validate.BUDGETS["lod1_ratio"])
        lod1_tris = asset.tri_count(lod1)
        bpy.data.objects.remove(lod1)
        rep = validate.validate(ob, lod1_tris, gen.BUDGET, b.stats, getattr(gen, "CHECKS", {}))
        reports[aid] = rep
        masks[aid] = validate.silhouette_masks(ob)
        mesh_path = out / f"{aid}.fbx"
        val_path = out / f"{aid}.validation.json"
        if not args.no_export:
            export.export_fbx(ob, mesh_path)
        validate.write_json(rep, val_path)
        ghash = geometry_hash(ob)
        coll = dict(getattr(gen, "COLLISION", {"fidelity": "Default"}))
        boxes = [{"name": cb["name"],
                  "center": [round(c, 3) for c in export.blender_to_roblox(cb["center"])],
                  "size": [round(c, 3) for c in export.size_to_roblox(cb["size"])]} for cb in b.collision_boxes]
        entries.append({
            "id": aid,
            "generator": gen.NAME,
            "generator_version": gen.VERSION,
            "category": gen.CATEGORY,
            "kingdom": params.get("kingdom"),
            "params": {k: v for k, v in params.items() if k != "seed"},
            "seed": seed,
            "budget_class": gen.BUDGET,
            "dimensions_studs": rep["size_studs"],
            "triangles": {"lod0": rep["triangles"]["lod0"], "lod1": lod1_tris,
                          "budget_lod0": rep["triangles"]["budget_lod0"]},
            "material": asset.EXPORT_MATERIAL,
            "texture": f"exports/textures/{asset.PALETTE_IMAGE}.png",
            "collision": {"fidelity": coll.get("fidelity", "Default"), "boxes": boxes},
            "double_sided": False,
            "render_fidelity": getattr(gen, "RENDER_FIDELITY", "Automatic"),
            "files": {"mesh": f"exports/{aid}.fbx", "validation": f"exports/{aid}.validation.json"},
            "preview": f"previews/{gen.NAME}.jpg",
            "sockets": {k: [round(c, 3) for c in export.blender_to_roblox(v)] for k, v in sorted(b.sockets.items())},
            "validation_pass": rep["pass"],
            "geometry_hash": ghash,
            "review": manifest.review_for(gen.NAME, aid, ghash),
        })
        objs.append(ob)
        fails = [c["check"] for c in rep["checks"] if not c["pass"]]
        print(f"[{name}] {aid}: tris {rep['triangles']['lod0']}/{rep['triangles']['budget_lod0']} "
              f"lod1 {lod1_tris} size {rep['size_studs']} {'PASS' if rep['pass'] else 'FAIL ' + '; '.join(fails)}",
              flush=True)

    variation = validate.variation_report(masks)
    if expect is not None:  # --verify: compare with the committed fragment, write nothing
        ok = all(r["pass"] for r in reports.values()) and variation["pass"]
        got = {e["id"]: (e["geometry_hash"], e["triangles"]["lod0"]) for e in entries}
        want = {e["id"]: (e["geometry_hash"], e["triangles"]["lod0"]) for e in expect["assets"]}
        for aid in sorted(set(got) | set(want)):
            if got.get(aid) != want.get(aid):
                ok = False
                print(f"[{name}] VERIFY MISMATCH {aid}: committed {want.get(aid)} rebuilt {got.get(aid)}", flush=True)
        print(f"[{name}] verify {'PASS' if ok else 'FAIL'} ({len(got)} assets)", flush=True)
        return ok
    if not args.no_manifest:
        manifest.write_fragment(gen.NAME, entries, variation, {"seed": args.seed, "variants": n})
        manifest.merge()
    print(f"[{name}] variation: min silhouette diff {variation['min_pair_diff']} "
          f"(closest {variation['closest_pair']}) {'PASS' if variation['pass'] else 'FAIL'}", flush=True)

    sheet_info = None
    if not args.no_render:
        sheet_info = render_previews(gen, objs, entries, rdir, sc, hero_px, samples, quick)
    print(f"[{name}] done in {time.time() - t0:.0f}s; sheet {sheet_info}", flush=True)
    ok = all(r["pass"] for r in reports.values()) and variation["pass"]
    return ok


def render_previews(gen, objs, entries, rdir, sc, hero_px, samples, quick):
    import bpy

    from lib import contact, rig

    for ob in objs:
        rig.use_preview_material(ob)
    cam = rig.add_camera(sc, 30)
    tiles = []
    for ob, e in zip(objs, entries):
        for o in objs:
            o.hide_render = o is not ob
        mn, mx = rig.world_bounds([ob])
        h = mx.z - mn.z
        # proxy to the right and slightly behind the asset's centre line so it never hides small assets
        px = rig.add_character_proxy(sc, mx.x + 2.2 + max(0.0, 0.04 * h), mn.y + (mx.y - mn.y) * 0.65 + 0.8, 0, 0.4)
        hero = getattr(gen, "HERO_VIEW", {"azimuth": 35, "elevation": 20})
        rig.frame(sc, cam, [ob, px], hero["azimuth"], hero["elevation"])
        sc.render.resolution_x = sc.render.resolution_y = hero_px
        path = rdir / f"{e['id']}_hero.png"
        rig.render(sc, path)
        bpy.data.objects.remove(px)
        tiles.append((path, e["id"], f"{e['triangles']['lod0']} tris  {e['dimensions_studs']['x']:.0f}x"
                      f"{e['dimensions_studs']['y']:.0f}x{e['dimensions_studs']['z']:.0f} studs"
                      + (f"  {e['kingdom']}" if e["kingdom"] else "")))
    # gameplay-distance lineup
    for o in objs:
        o.hide_render = False
    gap = getattr(gen, "LINEUP_GAP", 4.0)
    sizes = []
    for o in objs:
        mn, mx = rig.world_bounds([o])
        sizes.append((mx.x - mn.x, mx.y - mn.y))
    total = sum(w for w, _ in sizes) + gap * (len(objs) - 1)
    x = -total / 2
    for o, (w, _) in zip(objs, sizes):
        o.location.x = x + w / 2
        x += w + gap
    front = max(d for _, d in sizes) / 2
    rig.add_character_proxy(sc, 0, -front - 5.0, 0, 0)
    # gameplay band 40-80 studs (or the generator's GAMEPLAY_DISTANCE): as close as possible, but never closer
    # than the distance at which every variant fits the 16:9 frame (70 deg vFOV), so no variant is cut off
    half_h = math.tan(math.radians(rig.ROBLOX_FOV_DEG) / 2) * 16 / 9
    fit = (total / 2 + 6) / half_h + front
    preferred = getattr(gen, "GAMEPLAY_DISTANCE", None) or min(80.0, max(40.0, fit))
    dist = max(preferred, fit)
    widened = dist > preferred + 0.5
    hgt = getattr(gen, "GAMEPLAY_HEIGHT", 12.0)
    tallest = max(rig.world_bounds([o])[1].z for o in objs)
    rig.gameplay_camera(sc, cam, (0, 0, min(tallest * 0.45, 25)), dist, hgt, 0)
    sc.render.resolution_x, sc.render.resolution_y = (640, 360) if quick else (1280, 720)
    strip = rdir / f"{gen.NAME}_gameplay.png"
    rig.render(sc, strip)
    if not contact.available():
        print("contact sheet skipped: Pillow not available (renders are in", rdir, ")")
        return None
    title = f"{gen.NAME} v{gen.VERSION}  -  {len(objs)} variants  -  FORGE-02"
    sub = (f"hero 3/4 views with a 5.5-stud character proxy; bottom: gameplay view, {dist:.0f} studs"
           + (f" (widened from {preferred:.0f} to fit all {len(objs)} variants)" if widened else "")
           + ", 70 deg FOV, single-sided like Roblox")
    res = contact.sheet(title, tiles, (strip, f"gameplay distance ~{dist:.0f} studs (Roblox default FOV)"),
                        cols=3, tile_px=300 if quick else 420, out=HERE / "previews" / f"{gen.NAME}.jpg",
                        subtitle=sub)
    return {"path": str(res[0].relative_to(HERE)), "bytes": res[1], "quality": res[2], "px": list(res[3])}


def main(argv):
    args = parse_args(argv)
    if args.list:
        print("\n".join(list_generators()))
        return 0
    if args.verify:
        from lib import manifest

        args.no_render = args.no_export = args.no_manifest = True
        ok = True
        for frag in manifest.fragments():
            bp = frag.get("build") or {}
            if frag["generator"] not in list_generators() or "variants" not in bp:
                print(f"[{frag['generator']}] verify FAIL: generator missing or fragment has no build params")
                ok = False
                continue
            args.seed, args.variants = bp["seed"], bp["variants"]
            ok = build_generator(frag["generator"], args, expect=frag) and ok
        print("VERIFY", "PASS" if ok else "FAIL")
        return 0 if ok else 1
    if args.merge_only:
        from lib import manifest

        manifest.refresh_reviews()
        manifest.merge()
        print("manifest merged")
        return 0
    names = list_generators() if args.all else (args.generator or [])
    if not names:
        print("nothing to build: pass --generator NAME or --all (see --list)")
        return 2
    unknown = [n for n in names if n not in list_generators()]
    if unknown:
        print("unknown generator(s):", unknown)
        return 2
    ok = True
    for n in names:
        ok = build_generator(n, args) and ok
    print("BUILD", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    code = main(sys.argv)
    if code:
        sys.exit(code)
