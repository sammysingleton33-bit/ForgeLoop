"""Rebuild Roblox primitive parts (from a Kit JSON dump) as Blender objects for preview renders.

Roblox part-local geometry, centred at the origin, +Y up, front = -Z (sources in blender/README.md
"Kit preview"): Block = box; Cylinder = axis along local X, diameter min(Y, Z); Ball = diameter
min(X, Y, Z); WedgePart = vertical face at +Z, slope descending to the front (-Z);
CornerWedgePart = apex above one corner (CORNER_APEX).

Coordinates: Roblox (X, Y, Z) -> Blender (-X, Z, Y), the inverse of lib/coords.py. A part's
world matrix in Blender is P @ CFrame with P = [[-1,0,0],[0,0,1],[0,1,0]] (det +1, no mirroring);
mesh vertices stay in Roblox part-local coordinates.
"""

import math

import bmesh
import bpy
from mathutils import Matrix

P = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

# unit-cube vertices (±0.5) in Roblox part-local axes. Verified 2026-10-12 against Studio-measured
# open-source renderers (EgoMoose Quickhull-lua vertices.lua; Cautioned Blender-Animations-Plugin
# primitive_shapes.py "matches Studio's OBJ export"; roblox-headless-renderer scene.js).
WEDGE_VERTS = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5),
               (-0.5, 0.5, 0.5), (0.5, 0.5, 0.5)]
WEDGE_FACES = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
CORNER_APEX = (0.5, 0.5, -0.5)
CORNER_VERTS = [(-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), CORNER_APEX]
CORNER_FACES = [(0, 1, 2, 3), (0, 4, 1), (1, 4, 2), (2, 4, 3), (3, 4, 0)]

ROUGHNESS = {"SmoothPlastic": 0.45, "Plastic": 0.55, "Metal": 0.35, "Glass": 0.15, "Neon": 0.5}

_mesh_cache = {}
_mat_cache = {}


def reset_cache():
    """Call after a scene reset (read_factory_settings frees the cached meshes/materials)."""
    _mesh_cache.clear()
    _mat_cache.clear()


def _mesh_from(name, verts, faces, smooth=False):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    return me


# Part subclasses that render as a plain block (dumps from older specs send the class name, not the shape)
BLOCK_CLASSES = {"Seat": "Block", "VehicleSeat": "Block", "SpawnLocation": "Block", "Part": "Block"}


def unit_mesh(kind):
    """Shared unit meshes; objects scale them by the part size."""
    kind = BLOCK_CLASSES.get(kind, kind)
    if kind in _mesh_cache:
        return _mesh_cache[kind]
    if kind == "Block":
        v = [(x, y, z) for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)]
        f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
        me = _mesh_from("kit_block", v, f)
    elif kind in ("WedgePart", "Wedge"):
        me = _mesh_from("kit_wedge", WEDGE_VERTS, WEDGE_FACES)
    elif kind in ("CornerWedgePart", "CornerWedge"):
        me = _mesh_from("kit_cornerwedge", CORNER_VERTS, CORNER_FACES)
    elif kind == "Cylinder":
        seg = 24
        v, f = [], []
        for x in (-0.5, 0.5):
            for i in range(seg):
                a = 2 * math.pi * i / seg
                v.append((x, math.cos(a) * 0.5, math.sin(a) * 0.5))
        for i in range(seg):
            j = (i + 1) % seg
            f.append((i, j, seg + j, seg + i))
        f.append(tuple(range(seg)))
        f.append(tuple(range(2 * seg - 1, seg - 1, -1)))
        me = _mesh_from("kit_cylinder", v, f, smooth=True)
        for p in me.polygons:
            p.use_smooth = len(p.vertices) == 4
    elif kind == "Ball":
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=0.5)
        me = bpy.data.meshes.new("kit_ball")
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = True
    else:
        raise ValueError(f"unknown part kind {kind}")
    _mesh_cache[kind] = me
    return me


def material(color, mat_name):
    key = (tuple(round(c, 3) for c in color), mat_name)
    if key in _mat_cache:
        return _mat_cache[key]
    m = bpy.data.materials.new(f"kit_{mat_name}_{len(_mat_cache)}")
    try:
        m.use_nodes = True
    except AttributeError:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    # Roblox colours are sRGB; Blender wants linear
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in color]
    bsdf.inputs["Base Color"].default_value = (*lin, 1)
    bsdf.inputs["Roughness"].default_value = ROUGHNESS.get(mat_name, 0.8)
    if mat_name == "Metal":
        bsdf.inputs["Metallic"].default_value = 0.6
    if mat_name not in ("SmoothPlastic", "Glass", "Metal", "Neon"):
        # a hint of the Roblox material pattern: soft value noise on the bump
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 1.6 if mat_name in ("Cobblestone", "Slate") else 4.0
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.25 if mat_name in ("Cobblestone", "Slate") else 0.12
        nt.links.new(tex.outputs["Fac"], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    _mat_cache[key] = m
    return m


def cframe_matrix(c):
    """Roblox CFrame components (x, y, z, R00..R22) -> 4x4 in Roblox space."""
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
    return Matrix(((r00, r01, r02, x), (r10, r11, r12, y), (r20, r21, r22, z), (0, 0, 0, 1)))


def build_model(entry, collection, offset=(0.0, 0.0, 0.0), transform=None):
    """Create Blender objects for one dumped model. `transform` is an optional Roblox-space 4x4
    (e.g. a placement CFrame) applied before the axis conversion. Returns the list of objects."""
    objs = []
    parts = entry["parts"] if isinstance(entry, dict) else entry
    pre = transform if transform is not None else Matrix.Identity(4)
    for p in parts:
        if p.get("transparency", 0) >= 0.99:
            continue
        kind = p["shape"] if p["class"] == "Part" else p["class"]
        sx, sy, sz = p["size"]
        if kind == "Cylinder":
            d = min(sy, sz)
            sy = sz = d
        elif kind == "Ball":
            d = min(sx, sy, sz)
            sx = sy = sz = d
        ob = bpy.data.objects.new(p["name"], unit_mesh(kind))
        ob.data = unit_mesh(kind)
        mat = material(p["color"], p["material"])
        ob.material_slots  # noqa: B018
        if not ob.data.materials:
            ob.data.materials.append(None)
        ob.material_slots[0].link = "OBJECT"
        ob.material_slots[0].material = mat
        ob.matrix_world = (Matrix.Translation(offset) @ P @ pre @ cframe_matrix(p["cframe"])
                           @ Matrix.Diagonal((sx, sy, sz, 1)))
        collection.objects.link(ob)
        objs.append(ob)
    return objs
