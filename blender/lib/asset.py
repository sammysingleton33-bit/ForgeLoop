"""Builder: collects Pieces from a generator and finalises ONE Roblox-ready mesh object.

Finalising = merge all pieces, assign palette UVs per face corner, triangulate, put the
pivot at base centre, one material that samples the shared palette texture.
"""

import os
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

from . import palette
from .geo import Piece

PALETTE_IMAGE = f"forge_palette_v{palette.PALETTE_VERSION}"
EXPORT_MATERIAL = "M_forge_palette"


TEXTURE_DIR = Path(__file__).resolve().parent.parent / "exports" / "textures"


def palette_path():
    return TEXTURE_DIR / f"{PALETTE_IMAGE}.png"


def write_palette_png(path=None):
    """Generate the palette PNG on disk (deterministic). FBX export embeds this file."""
    path = Path(path) if path else palette_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    part = path.with_name(f".{path.stem}.{os.getpid()}.png")  # atomic: parallel builds share it
    tmp = bpy.data.images.new(PALETTE_IMAGE + "_gen", palette.SIZE, palette.SIZE, alpha=False)
    tmp.pixels.foreach_set(palette.build_pixels())
    tmp.filepath_raw = str(part)
    tmp.file_format = "PNG"
    tmp.save()
    bpy.data.images.remove(tmp)
    os.replace(part, path)
    return path


def palette_image():
    """The shared palette image, loaded from its PNG (generated on first use)."""
    img = bpy.data.images.get(PALETTE_IMAGE)
    if img is None:
        path = palette_path()
        if not path.exists():
            write_palette_png(path)
        img = bpy.data.images.load(str(path))
        img.name = PALETTE_IMAGE
        img.colorspace_settings.name = "sRGB"
    return img


def export_material():
    """Plain Principled material: palette -> Base Color. This is what the FBX carries."""
    mat = bpy.data.materials.get(EXPORT_MATERIAL)
    if mat:
        return mat
    mat = bpy.data.materials.new(EXPORT_MATERIAL)
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = palette_image()
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    mat.use_backface_culling = True  # Roblox renders single-sided
    return mat


class Builder:
    def __init__(self, asset_id, seed):
        self.asset_id = asset_id
        self.rng = random.Random(seed)
        self.pieces = []
        self.stats = {}  # structural metrics a generator wants validated (see validate.py)
        self.sockets = {}  # name -> (x, y, z) Blender coords; reported in studs (Roblox axes)
        self.collision_boxes = []  # optional invisible collision Parts: dicts with center/size (Blender)

    def add(self, piece, color=None, **paint):
        if isinstance(piece, (list, tuple)):
            for p in piece:
                self.add(p, color, **paint)
            return piece
        if color is not None:
            piece.color = color
        if paint:
            piece.paint(**paint)
        if piece.tint is None:
            piece.tint = self.rng.uniform(0.15, 0.85)
        self.pieces.append(piece)
        return piece

    def socket(self, name, x, y, z):
        self.sockets[name] = (float(x), float(y), float(z))

    def collision_box(self, cx, cy, cz, sx, sy, sz, name=None):
        self.collision_boxes.append({"name": name or f"box{len(self.collision_boxes) + 1}",
                                     "center": (cx, cy, cz), "size": (sx, sy, sz)})

    def count_tag(self, tag):
        return sum(1 for p in self.pieces if p.tag == tag)

    @property
    def tris(self):
        return sum(p.tris for p in self.pieces)

    # ------------------------------------------------------------------ finalise
    def _v01(self, piece, z, zmin, zmax, gmin, gmax):
        g = piece.grad
        if g is None:
            g = ("range", 0.3, 0.85)
        if g == "flat":
            return 0.6
        if isinstance(g, (int, float)):
            return float(g)
        if g == "global":
            return (z - gmin) / max(1e-6, gmax - gmin)
        lo, hi = (0.0, 1.0)
        mode = "local"
        if isinstance(g, tuple):
            mode, lo, hi = g if len(g) == 3 else ("range", g[0], g[1])
            if mode == "grange":
                t = (z - gmin) / max(1e-6, gmax - gmin)
                return lo + (hi - lo) * t
        t = (z - zmin) / max(1e-6, zmax - zmin)
        return lo + (hi - lo) * t

    def finalize(self, name=None):
        name = name or self.asset_id
        verts, faces, face_cols, face_smooth, face_piece = [], [], [], [], []
        for pi, p in enumerate(self.pieces):
            o = len(verts)
            verts.extend(p.verts)
            cols = p.face_colors or [p.color] * len(p.faces)
            smooth = p.face_smooth or [p.smooth] * len(p.faces)
            for f, c, sm in zip(p.faces, cols, smooth):
                if len(set(f)) < 3:
                    continue
                faces.append(tuple(i + o for i in f))
                face_cols.append(c)
                face_smooth.append(sm and p.smooth is not False if p.face_smooth else p.smooth)
                face_piece.append(pi)
        for c in set(face_cols):
            if c not in palette.INDEX:
                raise KeyError(f"{self.asset_id}: unknown palette colour {c!r}")

        # pivot: base centre
        xs = [v.x for v in verts]
        ys = [v.y for v in verts]
        zs = [v.z for v in verts]
        shift = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
        verts = [v - shift for v in verts]
        self.sockets = {k: tuple(Vector(s) - shift) for k, s in self.sockets.items()}
        for cb in self.collision_boxes:
            cb["center"] = tuple(Vector(cb["center"]) - shift)
        gmin, gmax = 0.0, max(zs) - min(zs)
        piece_z = []
        for p in self.pieces:
            pz = [v.z - shift.z for v in p.verts] or [0.0]
            piece_z.append((min(pz), max(pz)))

        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(v) for v in verts], [], faces)
        me.validate(clean_customdata=False)
        uv = me.uv_layers.new(name="UVMap")
        uvd = uv.data
        for poly in me.polygons:
            fi = poly.index
            p = self.pieces[face_piece[fi]]
            zmin, zmax = piece_z[face_piece[fi]]
            poly.use_smooth = face_smooth[fi]
            col = face_cols[fi]
            for li in poly.loop_indices:
                z = me.vertices[me.loops[li].vertex_index].co.z
                v01 = self._v01(p, z, zmin, zmax, gmin, gmax)
                uvd[li].uv = palette.swatch_uv(col, p.tint, v01)

        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY", ngon_method="BEAUTY")
        bm.to_mesh(me)
        bm.free()
        me.update()

        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(export_material())
        obj["forge_asset_id"] = self.asset_id
        return obj


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def make_lod1(obj, ratio):
    """Blender-side LOD1 (preview/budget only; Roblox generates its own render LODs)."""
    lod = obj.copy()
    lod.data = obj.data.copy()
    lod.name = obj.name + "_lod1"
    bpy.context.scene.collection.objects.link(lod)
    mod = lod.modifiers.new("dec", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = max(0.05, min(1.0, ratio))
    mod.use_collapse_triangulate = True
    dg = bpy.context.evaluated_depsgraph_get()
    ev = lod.evaluated_get(dg)
    new_me = bpy.data.meshes.new_from_object(ev)
    lod.modifiers.clear()
    old = lod.data
    lod.data = new_me
    bpy.data.meshes.remove(old)
    return lod


__all__ = ["Builder", "Piece", "palette_image", "export_material", "tri_count", "make_lod1",
           "PALETTE_IMAGE", "EXPORT_MATERIAL"]
