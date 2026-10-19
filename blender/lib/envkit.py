"""FL-0136 phase 1: the environment / architecture style comparison (D-057 (3)), three sources for the same subjects.

  S1  the project-original FL-0013 generators (castle_keep, house_cottage, ...), built in-process, palette texture baked to
      vertex colours exactly like the other sources
  S2  KayKit Medieval Hexagon Pack 1.0 (CC0, Kay Lousberg): glTF read from a GITIGNORED cache (blender/scripts/fetch_kaykit.sh pins
      the commit), atlas baked to vertex colours, fitted uniformly to the Kit footprint; NOTHING from the pack is committed
  S3  the current part-built Kit (primitives), dumped by blender/scripts/lune/EnvDump.spec.luau and rebuilt by lib/kitparts.py
  B   our own style-B wheat (wheat_b), for the subject the pack has no crop for

Everything is in ROBLOX axes (x right, y up, front -Z, studs) like the character kit; `fit_footprint` puts the base on y = 0, centres
the footprint on the origin and scales uniformly to the largest size that fits. Blender renders are not Studio renders.
"""

import hashlib
import importlib
import json
import math
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
REPO = HERE.parent

# ------------------------------------------------------------------------------------------------ provenance (S2)
KAYKIT_URL = "https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0"
KAYKIT_COMMIT = "84fa4e91af6a88989be7c99e0891cede11f2ca38"
KAYKIT_LICENSE = "Creative Commons Zero (CC0 1.0); LICENSE.txt in the repository root"
KAYKIT_CACHE = HERE / "exports" / ".cache" / "kaykit" / "hexagon"
KAYKIT_GLTF = KAYKIT_CACHE / "addons/kaykit_medieval_hexagon_pack/Assets/gltf"
SOURCES_JSON = HERE / "lib" / "envkit_sources.json"  # committed: path -> sha256 of every pack file the comparison reads

HUE = {"crimson": "red", "azure": "blue", "emerald": "green", "gold": "yellow"}  # kingdom -> KayKit / FL-0013 hue name


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def kk_files(rel):
    """Every file of one KayKit model: the glTF, its bin and the atlas it samples."""
    p = KAYKIT_GLTF / rel
    gl = json.loads(p.with_suffix(".gltf").read_text())
    files = [p.with_suffix(".gltf")] + [p.parent / b["uri"] for b in gl.get("buffers", [])]
    files += [p.parent / i["uri"] for i in gl.get("images", [])]
    return files


def pin_sources(rels, write=False):
    """sha256 of the pack files used. With `write`, record them in envkit_sources.json; otherwise verify against it."""
    got = {"repo": KAYKIT_URL, "commit": KAYKIT_COMMIT, "license": KAYKIT_LICENSE,
           "license_sha256": sha256(KAYKIT_CACHE / "LICENSE.txt"), "files": {}}
    for rel in rels:
        for f in kk_files(rel):
            got["files"][str(f.relative_to(KAYKIT_CACHE))] = sha256(f)
    if write:
        old = json.loads(SOURCES_JSON.read_text()) if SOURCES_JSON.exists() else {"files": {}}
        got["files"] = {**old.get("files", {}), **got["files"]}
        SOURCES_JSON.write_text(json.dumps(got, indent=1, sort_keys=True) + "\n")
        return got
    want = json.loads(SOURCES_JSON.read_text())
    bad = [k for k, v in got["files"].items() if want["files"].get(k) != v]
    if bad or want["commit"] != KAYKIT_COMMIT or want["license_sha256"] != got["license_sha256"]:
        raise RuntimeError(f"KayKit source files differ from blender/lib/envkit_sources.json: {bad}")
    return got


# ------------------------------------------------------------------------------------------------ meshes -> M (Roblox axes)

def _object_to_m(obj, atlas, smooth_from_polys=True, flat=False):
    """Blender mesh object (house preview axes: front -Y, Z up) -> `M` in Roblox axes (front -Z) with per-corner colours
    sampled from `atlas` through the UVs. Per-polygon smooth flags are kept (S1); `flat` forces flat shading (glTF)."""
    import bpy

    from . import ckit_kaykit as KK
    from .ckit import M

    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    mw = obj.matrix_world
    verts = []
    for v in me.vertices:
        p = mw @ v.co
        verts.append((-p.x, p.z, p.y))  # preview (X, Y, Z) -> Roblox (-X, Z, Y): a proper rotation, winding kept
    uv = me.uv_layers.active.data if me.uv_layers.active else None
    faces, cc, sm = [], [], []
    for lt in me.loop_triangles:
        faces.append(tuple(lt.vertices))
        cc.append([KK.sample(atlas, *uv[li].uv) if uv else (0.8, 0.8, 0.8) for li in lt.loops])
        sm.append(False if flat or not smooth_from_polys else bool(me.polygons[lt.polygon_index].use_smooth))
    m = M(verts, faces, color=(0.8, 0.8, 0.8), smooth=False)
    m.cc = cc
    m.s = sm
    ev.to_mesh_clear()
    return m


def _merge(ms):
    from .ckit import merge

    out = merge(*ms)
    return out


def kk_load(rel, flat=True):
    """One KayKit model (relative to the pack's Assets/gltf, no extension) as an `M` in Roblox axes, atlas baked to colours."""
    import bpy

    from . import ckit_kaykit as KK

    p = KAYKIT_GLTF / (rel + ".gltf")
    if not p.exists():
        raise FileNotFoundError(f"{p}: run bash blender/scripts/fetch_kaykit.sh")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(p))
    objs = [o for o in bpy.data.objects if o not in before]
    # a stable order across the hue variants (their object names differ by the hue suffix), so faces can be compared one to one
    objs.sort(key=lambda o: o.name.replace("_red", "").replace("_blue", "").replace("_green", "").replace("_yellow", ""))
    atlas = KK.load_atlas(p.parent / "hexagons_medieval.png")
    ms = [_object_to_m(o, atlas, flat=flat) for o in objs if o.type == "MESH"]
    for o in objs:
        bpy.data.objects.remove(o)
    return _merge(ms)


def s1_variants(gen_name, seed=7):
    gen = importlib.import_module(f"generators.{gen_name}")
    n = getattr(gen, "DEFAULT_VARIANTS", 6)
    out = []
    for i, params in enumerate(gen.variants(n, seed)):
        aid = gen.asset_id(i, params) if hasattr(gen, "asset_id") else f"{gen.NAME}_{i + 1:02d}"
        out.append((aid, i, params))
    return gen, out


def s1_load(asset_id, seed=7):
    """One FL-0013 generator asset (e.g. 'castle_keep_red_01') built in-process, palette baked to vertex colours."""
    import bpy

    from . import asset
    from . import ckit_kaykit as KK

    gen_name = asset_id.rsplit("_", 1)[0]
    cands = [gen_name] + ["_".join(asset_id.split("_")[:k]) for k in (3, 2)]
    for name in cands:
        try:
            gen, vs = s1_variants(name, seed)
        except ModuleNotFoundError:
            continue
        hit = [(aid, i, params) for aid, i, params in vs if aid == asset_id]
        if hit:
            break
    else:
        raise KeyError(asset_id)
    aid, i, params = hit[0]
    asset.write_palette_png()
    b = asset.Builder(aid, int(params.get("seed", seed * 1000 + i)))
    gen.build(b, params)
    ob = b.finalize()
    atlas = KK.load_atlas(asset.palette_path())
    m = _object_to_m(ob, atlas)
    bpy.data.objects.remove(ob)
    return m


# ------------------------------------------------------------------------------------------------ fitting

def bbox(m):
    (x0, y0, z0), (x1, y1, z1) = m.bounds()
    return (x0, y0, z0), (x1, y1, z1)


def fit_footprint(m, fx, fz, max_height=None):
    """Uniform scale to the largest size whose XZ box fits (fx, fz), footprint centred on the origin, base on y = 0.

    The centre is the bounding-box centre. Returns (m, report): scale, resulting XZ size, the footprint used, how much of it the
    box fills, and the height."""
    (x0, y0, z0), (x1, y1, z1) = bbox(m)
    sx, sz = fx / max(1e-9, x1 - x0), fz / max(1e-9, z1 - z0)
    s = min(sx, sz)
    if max_height:
        s = min(s, max_height / max(1e-9, y1 - y0))
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    m.map(lambda p: ((p[0] - cx) * s, (p[1] - y0) * s, (p[2] - cz) * s))
    (a0, b0, c0), (a1, b1, c1) = bbox(m)
    rep = {"scale": round(s, 3), "size": [round(a1 - a0, 2), round(b1 - b0, 2), round(c1 - c0, 2)], "footprint": [fx, fz],
           "x_fill": round((a1 - a0) / fx, 3), "z_fill": round((c1 - c0) / fz, 3), "height": round(b1 - b0, 2), "tris": m.tris,
           "xz_within": bool(a1 - a0 <= fx + 1e-6 and c1 - c0 <= fz + 1e-6)}
    return m, rep


def fit_height(m, h, ground_centre=True):
    """Free-standing nature: scale uniformly to height `h`, base on y = 0, XZ centre on the origin."""
    (x0, y0, z0), (x1, y1, z1) = bbox(m)
    s = h / max(1e-9, y1 - y0)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    m.map(lambda p: ((p[0] - cx) * s, (p[1] - y0) * s, (p[2] - cz) * s))
    (a0, b0, c0), (a1, b1, c1) = bbox(m)
    return m, {"scale": round(s, 3), "size": [round(a1 - a0, 2), round(b1 - b0, 2), round(c1 - c0, 2)], "height": round(b1 - b0, 2),
               "tris": m.tris}


def placed(m, x=0.0, z=0.0, yaw=0.0, y=0.0):
    """Copy of `m` turned `yaw` degrees about +y and moved to (x, y, z) (Roblox axes)."""
    out = m.copy()
    if yaw:
        out.rot(yaw, "y")
    return out.move(x, y, z)


# ------------------------------------------------------------------------------------------------ S3 (part-built Kit dump)

def s3_bbox(entry):
    """Axis-aligned bounds of the visible parts of a dumped model (rotated boxes by their projected extents)."""
    mn, mx = [1e9] * 3, [-1e9] * 3
    for p in entry["parts"]:
        if p.get("transparency", 0) >= 0.99:
            continue
        c = p["cframe"]
        pos, R = c[:3], [c[3:6], c[6:9], c[9:12]]
        h = [s / 2 for s in p["size"]]
        for i in range(3):
            ext = sum(abs(R[i][j]) * h[j] for j in range(3))
            mn[i] = min(mn[i], pos[i] - ext)
            mx[i] = max(mx[i], pos[i] + ext)
    return tuple(mn), tuple(mx)


def s3_report(entry, fp=None):
    mn, mx = s3_bbox(entry)
    rep = {"size": [round(mx[i] - mn[i], 2) for i in range(3)], "x_range": [round(mn[0], 2), round(mx[0], 2)],
           "z_range": [round(mn[2], 2), round(mx[2], 2)], "height": round(mx[1] - mn[1], 2), "parts": entry.get("partCount")}
    if fp:
        rep["footprint"] = list(fp)
        rep["xz_within"] = bool(mx[0] - mn[0] <= fp[0] + 1e-6 and mx[2] - mn[2] <= fp[1] + 1e-6)
        rep["front_overhang"] = round(max(0.0, -mn[2] - fp[1] / 2), 2)
    return rep


# ------------------------------------------------------------------------------------------------ own style-B wheat

def wheat_b(stage=3, w=38.0, d=28.0, seed=7):
    """Style-B wheat field (faceted, flat colours, a chunky mass instead of thin spikes) on a soil bed, in Roblox axes.

    stage 1 = green shoots, 2 = half grown and turning, 3 = ripe golden with ears. Six rows of overlapping stalk wedges; each
    row is a low tapered block of stalks plus a ridge of tilted ears; sheaves on the border at stage 3."""
    import random

    from .ckit import box, cone, cyl, hull, merge, mix, rgb

    rng = random.Random(seed * 131 + stage)
    soil, ridge = rgb(96, 70, 44), rgb(112, 82, 52)
    cols = {1: (rgb(112, 168, 70), rgb(142, 192, 84)), 2: (rgb(150, 178, 64), rgb(206, 190, 84)),
            3: (rgb(214, 170, 62), rgb(244, 208, 96))}[stage]
    stalk_c, ear_c = cols
    height = {1: 0.7, 2: 1.7, 3: 2.5}[stage]
    parts = [box(w, 0.5, d, color=soil, smooth=False, tag="soil").move(0, 0.25, 0)]
    rows = 6
    pitch = (d - 3.0) / rows
    for r in range(rows):
        z = -d / 2 + 1.8 + pitch * (r + 0.5)
        parts.append(box(w - 3.0, 0.22, pitch * 0.55, color=ridge, smooth=False, tag="ridge").move(0, 0.55, z))
        nclump = 15
        for k in range(nclump):
            x = -(w - 5.0) / 2 + (w - 5.0) * (k + 0.5) / nclump + rng.uniform(-0.25, 0.25)
            hh = height * rng.uniform(0.82, 1.12)
            shade = rng.uniform(0.9, 1.06)
            c = tuple(min(1.0, v * shade) for v in stalk_c)
            # a clump = a tapered chunky wedge of stalks (wide at the ground, narrow at the top) with a faceted ear cap
            base_w = (w - 5.0) / nclump * 1.06
            a = base_w / 2
            b = pitch * 0.34
            pts = [(-a, 0.5, -b), (a, 0.5, -b), (-a, 0.5, b), (a, 0.5, b),
                   (-a * 0.55, 0.5 + hh, -b * 0.5), (a * 0.55, 0.5 + hh, -b * 0.5), (-a * 0.55, 0.5 + hh, b * 0.5), (a * 0.55, 0.5 + hh, b * 0.5)]
            clump = hull([(px + x, py, pz + z) for px, py, pz in pts], color=c, smooth=False, tag="stalks")
            parts.append(clump)
            if stage >= 2:
                ec = mix(ear_c, c, 0.0 if stage == 3 else 0.35)
                e = cone(0.5 if stage == 3 else 0.38, 1.1 if stage == 3 else 0.7, seg=4, y0=0.5 + hh - 0.1, color=ec, smooth=False, tag="ear")
                e.rot(rng.uniform(-10, 10), "z", pivot=(0, 0.5 + hh, 0)).move(x, 0, z + rng.uniform(-0.2, 0.2))
                parts.append(e)
    if stage == 3:
        for sx in (-w * 0.33, 0.0, w * 0.33):
            sh = merge(cone(0.9, 2.4, seg=5, y0=0.5, color=rgb(226, 184, 82), smooth=False, tag="sheaf"),
                       cyl(0.9, 0.6, 0.5, seg=5, y0=0.5, color=rgb(186, 150, 64), smooth=False, tag="sheaf"))
            parts.append(sh.move(sx + rng.uniform(-1, 1), 0, d / 2 - 0.9))
    return merge(*parts)
