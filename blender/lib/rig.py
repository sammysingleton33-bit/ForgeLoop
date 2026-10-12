"""Preview rig that imitates how assets read in Roblox.

- Single-sided rendering (backfaces transparent in Cycles: Roblox culls backfaces).
- One warm sun + cool sky fill, a neutral ground, a 5.5-stud character proxy for scale.
- Hero 3/4 view per asset, and a gameplay view from 40-80 studs with Roblox's default
  70 degree vertical field of view.
"""

import math

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

from .asset import EXPORT_MATERIAL, palette_image

PREVIEW_MATERIAL = "M_forge_palette_preview"
ROBLOX_FOV_DEG = 70.0  # Roblox default Camera.FieldOfView (vertical)
PROXY_HEIGHT = 5.5


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "NONE"  # 1 Blender unit = 1 stud (Roblox docs: art/blender.md)
    return sc


def setup_render(sc, width=640, height=640, samples=40, look="AgX - Punchy"):
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.cycles.diffuse_bounces = 2
    sc.cycles.glossy_bounces = 1
    sc.cycles.transparent_max_bounces = 8
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    vs = sc.view_settings
    vs.view_transform = "AgX"
    try:
        vs.look = look
    except TypeError:
        vs.look = "None"
    vs.exposure = 0.0
    sc.render.use_persistent_data = True


def _nodes(owner):
    try:
        owner.use_nodes = True
    except AttributeError:
        pass
    return owner.node_tree


def setup_world(sc, sky_top=(0.30, 0.55, 0.92), sky_horizon=(0.80, 0.88, 0.96), fill=(0.55, 0.68, 0.85),
                fill_strength=0.65):
    w = bpy.data.worlds.new("forge_sky")
    sc.world = w
    nt = _nodes(w)
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*sky_horizon, 1)
    ramp.color_ramp.elements[1].position = 0.45
    ramp.color_ramp.elements[1].color = (*sky_top, 1)
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    nt.links.new(ramp.outputs["Color"], bg_cam.inputs["Color"])
    bg_cam.inputs["Strength"].default_value = 1.0
    bg_light = nt.nodes.new("ShaderNodeBackground")
    bg_light.inputs["Color"].default_value = (*fill, 1)
    bg_light.inputs["Strength"].default_value = fill_strength
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs["Fac"])
    nt.links.new(bg_light.outputs["Background"], mix.inputs[1])
    nt.links.new(bg_cam.outputs["Background"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def add_sun(sc, elevation_deg=46, azimuth_deg=-40, strength=4.6, color=(1.0, 0.92, 0.78), angle_deg=2.5):
    ld = bpy.data.lights.new("forge_sun", "SUN")
    ld.energy = strength
    ld.color = color
    ld.angle = math.radians(angle_deg)
    sun = bpy.data.objects.new("forge_sun", ld)
    sc.collection.objects.link(sun)
    # sun direction: light travels along -Z of the object
    el, az = math.radians(elevation_deg), math.radians(azimuth_deg)
    sun.rotation_euler = (math.pi / 2 - el, 0.0, az + math.pi / 2)
    return sun


def _flat_material(name, rgb, rough=0.9):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    nt = _nodes(m)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def add_ground(sc, size=4000.0, rgb=(0.36, 0.37, 0.33), z=0.0):
    me = bpy.data.meshes.new("forge_ground")
    s = size / 2
    me.from_pydata([(-s, -s, z), (s, -s, z), (s, s, z), (-s, s, z)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("forge_ground", me)
    sc.collection.objects.link(ob)
    ob.data.materials.append(_flat_material("M_rig_ground", rgb))
    return ob


def preview_material():
    """Palette material + Roblox-style single-sided rendering for Cycles."""
    m = bpy.data.materials.get(PREVIEW_MATERIAL)
    if m:
        return m
    m = bpy.data.materials.new(PREVIEW_MATERIAL)
    nt = _nodes(m)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = palette_image()
    tex.interpolation = "Linear"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.25
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(bsdf.outputs["BSDF"], mix.inputs[1])
    nt.links.new(tr.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    m.use_backface_culling = True
    return m


def use_preview_material(obj):
    pm = preview_material()
    for slot in obj.material_slots:
        if slot.material and slot.material.name.startswith(EXPORT_MATERIAL):
            slot.material = pm


def add_character_proxy(sc, x=0.0, y=0.0, z=0.0, rot_z=0.0, rgb=(0.62, 0.66, 0.74)):
    """Blocky R15-like proxy, 5.5 studs tall (legs 2.4, torso 2.0, head 1.1)."""
    import bmesh

    bm = bmesh.new()

    def blk(cx, cy, cz, sx, sy, sz):
        r = bmesh.ops.create_cube(bm, size=1.0)
        for v in r["verts"]:
            v.co.x = v.co.x * sx + cx
            v.co.y = v.co.y * sy + cy
            v.co.z = v.co.z * sz + cz

    blk(-0.5, 0, 1.2, 0.95, 0.95, 2.4)  # legs
    blk(0.5, 0, 1.2, 0.95, 0.95, 2.4)
    blk(0, 0, 3.4, 2.0, 1.0, 2.0)  # torso
    blk(-1.5, 0, 3.4, 0.95, 0.95, 2.0)  # arms
    blk(1.5, 0, 3.4, 0.95, 0.95, 2.0)
    blk(0, 0, 4.95, 1.15, 1.1, 1.1)  # head
    bevel_edges = list(bm.edges)
    bmesh.ops.bevel(bm, geom=bevel_edges, offset=0.08, segments=1, affect="EDGES", clamp_overlap=True)
    me = bpy.data.meshes.new("forge_proxy")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("forge_proxy", me)
    sc.collection.objects.link(ob)
    ob.location = (x, y, z)
    ob.rotation_euler = (0, 0, rot_z)
    ob.data.materials.append(_flat_material("M_rig_proxy", rgb, 0.6))
    return ob


def world_bounds(objs):
    pts = []
    for o in objs:
        for c in o.bound_box:
            pts.append(o.matrix_world @ Vector(c))
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def add_camera(sc, lens_fov_deg=30.0, name="forge_cam"):
    cd = bpy.data.cameras.new(name)
    cd.sensor_fit = "VERTICAL"
    cd.angle_y = math.radians(lens_fov_deg)
    cd.clip_start = 0.1
    cd.clip_end = 5000
    cam = bpy.data.objects.new(name, cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def aim(cam, target):
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def frame(sc, cam, objs, azimuth_deg=35.0, elevation_deg=22.0, margin=0.08, target_z_frac=0.45):
    """Place cam on a sphere around the objects so their bounds fill the frame (binary search)."""
    mn, mx = world_bounds(objs)
    centre = (mn + mx) / 2
    centre.z = mn.z + (mx.z - mn.z) * target_z_frac
    corners = [Vector((x, y, z)) for x in (mn.x, mx.x) for y in (mn.y, mx.y) for z in (mn.z, mx.z)]
    el, az = math.radians(elevation_deg), math.radians(azimuth_deg)
    direction = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    lo, hi = 0.5, 5000.0
    for _ in range(40):
        mid = (lo + hi) / 2
        cam.location = centre + direction * mid
        aim(cam, centre)
        bpy.context.view_layer.update()
        ok = True
        for c in corners:
            p = world_to_camera_view(sc, cam, c)
            if p.z <= 0 or not (margin <= p.x <= 1 - margin and margin <= p.y <= 1 - margin):
                ok = False
                break
        if ok:
            hi = mid
        else:
            lo = mid
    cam.location = centre + direction * hi
    aim(cam, centre)
    return hi


def gameplay_camera(sc, cam, target, distance=60.0, height=12.0, azimuth_deg=20.0):
    """Roblox-like third-person view: default 70 deg vertical FOV, from `distance` studs."""
    cam.data.sensor_fit = "VERTICAL"
    cam.data.angle_y = math.radians(ROBLOX_FOV_DEG)
    az = math.radians(azimuth_deg)
    t = Vector(target)
    cam.location = Vector((t.x + math.sin(az) * distance, t.y - math.cos(az) * distance, height))
    aim(cam, t)


def render(sc, path):
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    return path


def standard_stage(width=640, height=640, samples=40, ground_rgb=(0.42, 0.43, 0.38)):
    """Everything except the asset: render settings, sky, sun, ground. Returns scene."""
    sc = bpy.context.scene
    setup_render(sc, width, height, samples)
    setup_world(sc)
    add_sun(sc)
    add_ground(sc, rgb=ground_rgb)
    return sc
