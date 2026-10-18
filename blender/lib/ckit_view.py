"""Preview helpers for the character kit: piece sheets, lineups, portrait / gameplay / aerial cameras.

Pieces are rig-axes `M` meshes; Blender objects come from ckit.to_object (Z-up, front -Y). The preview imitates Roblox
(single-sided, vertex colours x MeshPart.Color); blender/lib/rig.py supplies the sky, sun and ground. Blender renders
are not Studio renders.
"""

import math

import bpy
from mathutils import Vector

from . import ckit, rig

ROBLOX_FOV = rig.ROBLOX_FOV_DEG
GRASS = (106, 168, 62)


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


QUICK = False  # Workbench engine: ~10x faster, no sun/sky (form + vertex colour check only)


def stage(w, h, samples=24, ground=GRASS, quick=None):
    from . import kitparts

    rig.reset_scene()
    kitparts.reset_cache()
    sc = rig.standard_stage(w, h, samples, ground_rgb=tuple(lin(c) for c in ground))
    sc.cycles.use_denoising = True
    if QUICK if quick is None else quick:
        sc.render.engine = "BLENDER_WORKBENCH"
        sh = sc.display.shading
        sh.light = "STUDIO"
        sh.color_type = "VERTEX"
        sh.show_shadows = True
        sh.shadow_intensity = 0.35
        sh.show_cavity = False
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.72, 0.8, 0.9)
        sc.view_settings.view_transform = "Standard"
    return sc


def set_tint(obj, rgb_tint, ao_cache=None):
    """Bake MeshPart.Color x vertex colours into the render colour layer (multiplied in sRGB, like Roblox's
    colour modulation is assumed to be; see rig.json notes). Keeps the original `Col` layer untouched."""
    me = obj.data
    src = me.color_attributes["Col"]
    dst = me.color_attributes.get("Cview")
    if dst is None:
        dst = me.color_attributes.new("Cview", "BYTE_COLOR", "CORNER")
    for i in range(len(me.loops)):
        c = src.data[i].color_srgb
        dst.data[i].color_srgb = (c[0] * rgb_tint[0], c[1] * rgb_tint[1], c[2] * rgb_tint[2], 1.0)
    me.color_attributes.active_color = dst


def view_material():
    mat = ckit.vertex_color_material("M_charkit_view")
    for n in mat.node_tree.nodes:
        if n.type == "ATTRIBUTE":
            n.attribute_name = "Cview"
    # backface transparency like the pipeline's preview material (Cycles ignores use_backface_culling)
    nt = mat.node_tree
    if not any(n.type == "NEW_GEOMETRY" for n in nt.nodes):
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
        nt.links.new(bsdf.outputs["BSDF"], mix.inputs[1])
        nt.links.new(tr.outputs["BSDF"], mix.inputs[2])
        nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def make(name, m, tint=(1.0, 1.0, 1.0), ao=0.22, facet=0.0, seed=0, location=(0.0, 0.0, 0.0), collection=None):
    obj, lo, hi = ckit.to_object(name, m, location=location, ao=ao, facet=facet, seed=seed, collection=collection)
    # preview convention of the house scenes: Roblox (x, y, z) -> Blender (-x, z, y), i.e. the authoring frame
    # (front +Y) turned 180 degrees about Z, so the character faces the default -Y camera
    obj.location = (-obj.location.x, -obj.location.y, obj.location.z)
    obj.rotation_euler = (0.0, 0.0, math.pi)
    set_tint(obj, tint)
    obj.data.materials.append(view_material())
    return obj


def bounds(objs):
    bpy.context.view_layer.update()
    return rig.world_bounds(objs)


def piece_sheet(items, out, cols=6, cell=300, yaw=28, elev=14, samples=20, facet=0.0, tints=None):
    """items: [(label, M)]. Renders all pieces in one frame on a grid (rig axes: x right, y up) from the front."""
    from PIL import Image, ImageDraw

    rows = (len(items) + cols - 1) // cols
    sc = stage(cell * cols, cell * rows, samples)
    objs = []
    # per-cell size = largest piece extent
    ext = 0.0
    for _, m in items:
        (x0, y0, z0), (x1, y1, z1) = m.bounds()
        ext = max(ext, x1 - x0, y1 - y0, z1 - z0)
    gap = ext * 1.15
    for i, (label, m) in enumerate(items):
        r, c = divmod(i, cols)
        (x0, y0, z0), (x1, y1, z1) = m.bounds()
        cx, cy, cz = (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2
        o = make(label, m, (tints or {}).get(label, (1, 1, 1)), facet=facet, seed=i)
        # move to the cell centre (rig x, y) then yaw about the object's vertical axis
        o.location = Vector((c * gap, 0.0, -r * gap))
        o.rotation_euler = (0, 0, math.pi + math.radians(yaw))
        objs.append(o)
    cam = rig.add_camera(sc, 22)
    bpy.context.view_layer.update()
    mn, mx = rig.world_bounds(objs)
    centre = Vector(((cols - 1) / 2 * gap, 0.0, -(rows - 1) / 2 * gap))
    cam.data.type = "ORTHO"
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.ortho_scale = cols * gap
    el = math.radians(elev)
    cam.location = centre + Vector((0, -60 * math.cos(el), 60 * math.sin(el)))
    rig.aim(cam, centre)
    for ob in bpy.data.objects:
        if ob.name == "forge_ground":
            ob.location.z = mn.z - 1.0
    sc.render.resolution_x, sc.render.resolution_y = cell * cols, cell * rows
    rig.render(sc, out)
    im = Image.open(out).convert("RGB")
    d = ImageDraw.Draw(im)
    for i, (label, m) in enumerate(items):
        r, c = divmod(i, cols)
        d.text((c * cell + 6, r * cell + 4), f"{label} {m.copy().triangulate().tris}", fill=(20, 20, 20))
    im.save(out)
    return out
