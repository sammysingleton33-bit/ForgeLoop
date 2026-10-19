"""KayKit (CC0, Kay Lousberg) -> rigid kit pieces (FL-0135, D-057 (9)): import a pack GLB read-only, bake its gradient atlas
into per-corner vertex colours, decimate toward the triangle budget with the colour boundaries protected, and fit each
body part into the rig envelope of Kit/Character.luau.

Source files are NEVER committed (D-057 (13)): `tools` fetch the pinned repo into a gitignored cache and this module reads
from there. Only the derived pieces (blender/exports, rig.json, the manifest row with the source sha256) are committed.
"""

import hashlib
from pathlib import Path

import numpy as np

from .ckit import M

ATLAS_CACHE = {}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_atlas(png_path):
    """Atlas as a float array (H, W, 3) in sRGB 0..1, row 0 = top of the image."""
    from PIL import Image

    key = str(png_path)
    if key not in ATLAS_CACHE:
        ATLAS_CACHE[key] = np.asarray(Image.open(png_path).convert("RGB"), dtype=np.float32) / 255.0
    return ATLAS_CACHE[key]


def sample(atlas, u, v):
    """Bilinear sample at glTF-imported (Blender) UV: v = 0 is the bottom of the image."""
    h, w, _ = atlas.shape
    x = min(max(u, 0.0), 1.0) * (w - 1)
    y = (1.0 - min(max(v, 0.0), 1.0)) * (h - 1)
    x0, y0 = int(x), int(y)
    x1, y1 = min(x0 + 1, w - 1), min(y0 + 1, h - 1)
    fx, fy = x - x0, y - y0
    a = atlas[y0, x0] * (1 - fx) + atlas[y0, x1] * fx
    b = atlas[y1, x0] * (1 - fx) + atlas[y1, x1] * fx
    c = a * (1 - fy) + b * fy
    return (float(c[0]), float(c[1]), float(c[2]))


def import_glb(path):
    """Import a GLB into the current scene; returns {mesh object name: object} for the new objects."""
    import bpy

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return {o.name: o for o in bpy.data.objects if o not in before}


def to_M(obj, atlas, xf=None):
    """Blender mesh object (preview axes: front -Y) -> `M` in rig axes (front -Z) with baked per-corner colours.

    xf maps a point in rig axes after the axis conversion (e.g. a part's fit transform).
    """
    import bpy

    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    mw = obj.matrix_world
    verts = []
    for v in me.vertices:
        p = mw @ v.co
        verts.append((-p.x, p.z, p.y))  # preview (X, Y, Z) -> rig (-X, Z, Y)
    uv = me.uv_layers.active.data if me.uv_layers.active else None
    faces, cc = [], []
    for lt in me.loop_triangles:
        f = tuple(lt.vertices)
        cols = []
        for li in lt.loops:
            cols.append(sample(atlas, *uv[li].uv) if uv else (0.8, 0.8, 0.8))
        faces.append(f)
        cc.append(cols)
    m = M(verts, faces, color=(0.8, 0.8, 0.8), smooth=True)
    m.cc = cc
    ev.to_mesh_clear()
    # preview -> rig is a proper rotation: winding is preserved
    return m


def bounds_of(m):
    return m.bounds()


def fit(m, target_min, target_max, keep_aspect=False):
    """Scale + translate `m` so its bounding box maps onto [target_min, target_max] (per axis)."""
    (x0, y0, z0), (x1, y1, z1) = m.bounds()
    sx = (target_max[0] - target_min[0]) / max(1e-9, x1 - x0)
    sy = (target_max[1] - target_min[1]) / max(1e-9, y1 - y0)
    sz = (target_max[2] - target_min[2]) / max(1e-9, z1 - z0)
    if keep_aspect:
        sx = sy = sz = min(sx, sy, sz)
    cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
    tx, ty, tz = [(a + b) / 2 for a, b in zip(target_min, target_max)]
    return m.map(lambda p: ((p[0] - cx) * sx + tx, (p[1] - cy) * sy + ty, (p[2] - cz) * sz + tz))


def edge_importance(m, eps=1e-4):
    """Per-vertex weight in 0..1 (indexed like m.v, but welded by POSITION): high where the baked colour changes
    between the faces meeting there (eyes, belts, trims, hair lines)."""
    lo, hi = {}, {}
    for f, cols in zip(m.f, m.cc):
        for vi, c in zip(f, cols):
            p = m.v[vi]
            key = (round(p[0] / eps), round(p[1] / eps), round(p[2] / eps))
            if key not in lo:
                lo[key] = list(c)
                hi[key] = list(c)
            else:
                for k in range(3):
                    lo[key][k] = min(lo[key][k], c[k])
                    hi[key][k] = max(hi[key][k], c[k])
    out = []
    for p in m.v:
        key = (round(p[0] / eps), round(p[1] / eps), round(p[2] / eps))
        a, b = lo[key], hi[key]
        out.append(min(1.0, (abs(b[0] - a[0]) + abs(b[1] - a[1]) + abs(b[2] - a[2])) * 2.5))
    return out


def decimate(m, target_tris, protect=0.0, symmetric=True, close=True):
    """Collapse-decimate to about `target_tris` triangles; colours are re-sampled from the original surface (nearest point).

    protect (0..1): how strongly vertices on colour boundaries resist collapse (decimate vertex-group bias: a LOW group
    weight keeps a vertex)."""
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree

    src = m
    imp = edge_importance(m) if protect > 0 else [0.0] * len(m.v)
    # weld by position (glTF import splits vertices at UV seams) keeping the max importance
    key, remap, wv, wi = {}, [], [], []
    for i, p in enumerate(m.v):
        k = (round(p[0] / 1e-4), round(p[1] / 1e-4), round(p[2] / 1e-4))
        if k not in key:
            key[k] = len(wv)
            wv.append(p)
            wi.append(imp[i])
        remap.append(key[k])
        wi[key[k]] = max(wi[key[k]], imp[i])
    wf = []
    for f in m.f:
        g = tuple(remap[j] for j in f)
        if len(set(g)) == 3:
            wf.append(g)
    me = bpy.data.meshes.new("kk_src")
    me.from_pydata([(-v[0], v[2], v[1]) for v in wv], [], wf)  # rig -> preview axes
    me.update()
    if close:
        import bmesh

        bm = bmesh.new()
        bm.from_mesh(me)
        edges = [e for e in bm.edges if e.is_boundary]
        if edges:
            bmesh.ops.holes_fill(bm, edges=edges, sides=0)
            bmesh.ops.triangulate(bm, faces=list(bm.faces))
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(me)
        bm.free()
        wi = wi + [0.0] * (len(me.vertices) - len(wi))
        wf = [tuple(p.vertices) for p in me.polygons]
    obj = bpy.data.objects.new("kk_src", me)
    bpy.context.scene.collection.objects.link(obj)
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(0.02, min(1.0, target_tris / max(1, len(wf))))
    mod.use_collapse_triangulate = True
    mod.use_symmetry = symmetric
    mod.symmetry_axis = "X"
    if protect > 0:
        vg = obj.vertex_groups.new(name="keep")
        for i, w in enumerate(wi):
            vg.add([i], max(0.0, 1.0 - w * min(1.0, protect)), "REPLACE")
        mod.vertex_group = "keep"
        mod.vertex_group_factor = 1.0
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    out = bpy.data.meshes.new_from_object(ev)
    verts = [(-v.co.x, v.co.z, v.co.y) for v in out.vertices]
    faces = [tuple(p.vertices) for p in out.polygons]
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(out)
    res = M(verts, faces, color=(0.8, 0.8, 0.8), smooth=True)
    # re-colour: per corner, the original colour at the nearest surface point (blended with the face centre)
    tree = BVHTree.FromPolygons([tuple(v) for v in src.v], [tuple(f) for f in src.f])
    res.cc = []
    for f in res.f:
        cen = Vector([sum(res.v[j][k] for j in f) / 3 for k in range(3)])
        cols = []
        for j in f:
            p = Vector(res.v[j]) * 0.65 + cen * 0.35
            loc, nrm, idx, dist = tree.find_nearest(p)
            cols.append(_interp(src, idx, loc))
        res.cc.append(cols)
    return res


def _interp(m, fi, loc):
    """Barycentric interpolation of the original corner colours at `loc` on triangle `fi`."""
    from mathutils import Vector
    from mathutils.geometry import barycentric_transform  # noqa: F401

    a, b, c = (Vector(m.v[j]) for j in m.f[fi])
    v0, v1, v2 = b - a, c - a, loc - a
    d00, d01, d11 = v0.dot(v0), v0.dot(v1), v1.dot(v1)
    d20, d21 = v2.dot(v0), v2.dot(v1)
    den = d00 * d11 - d01 * d01
    if abs(den) < 1e-12:
        return m.cc[fi][0]
    vv = (d11 * d20 - d01 * d21) / den
    ww = (d00 * d21 - d01 * d20) / den
    uu = 1.0 - vv - ww
    uu, vv, ww = max(0.0, uu), max(0.0, vv), max(0.0, ww)
    s = uu + vv + ww or 1.0
    ca, cb, cc = m.cc[fi]
    return tuple((ca[k] * uu + cb[k] * vv + cc[k] * ww) / s for k in range(3))
