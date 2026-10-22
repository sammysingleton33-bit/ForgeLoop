"""Render the AI Kingdoms world preview from the Lune world dump (FL-0055): a top-down map and oblique
views, so the layout, terrain, props and starting buildings can be reviewed before Studio (D-019).

  FORGE_WORLD_DUMP=/tmp/world.json lune run roblox/tests/harness/run.luau \
      --project games/game-001/default.project.json --specs games/game-001/tests/world WorldDump
  ~/forge-bpy/bin/python blender/scripts/render_world.py --json /tmp/world.json [--views top,valley] [--quick]

Writes blender/previews/world_<view>.jpg (<= 250 KB). Terrain colours match world/Lighting.luau
terrainColors; Roblox Terrain smoothing/textures and Lighting (Future, Atmosphere) are approximated.

Default-camera views (the visual upgrade, D-019). They stand where the ruler's camera stands (RulerCameraController overview, focus =
the plot spawn, yaw 0 = looking toward -Z, 16:9, vertical field of view as listed; the pitch follows the zoom linearly from 38 degrees at
zoom 40 to 65 at zoom 220):
  default_<kingdom>        the START view approved by FORGE-00 on 2026-10-19: zoom 70, FOV 55, pitch 42.5   (kingdom: crimson azure emerald gold)
  default_phone_<kingdom>  the same camera at 750 x 311
  far_<kingdom>            players zoom out: zoom 220, FOV 55, pitch 65 (the composition has to hold here too)
  legacy_<kingdom>         the camera of the B22 build the owner played: zoom 120, FOV 70, pitch 50
These views light the scene from the world/Lighting.luau preset in the dump (`lighting`): sun height from ClockTime
and GeographicLatitude (a sun path at the equinox), sun colour from ColorShift_Top, strength from Brightness, the sky fill from
OutdoorAmbient, the haze from Atmosphere, and the ColorCorrection grade applied after the render. It is a PREVIEW approximation
(the sun's compass direction, Atmosphere's falloff, Future shadows, bloom and Terrain shading are not Roblox's own): it tells you
which way a change moves the picture, not how Studio draws it.
  --tag NAME       suffix of the output files (before / after pairs): world_default_crimson_<tag>.jpg
  --out-dir DIR    where the JPEGs go (default blender/previews)
"""

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

from lib import contact, kitparts, rig  # noqa: E402

TERRAIN_RGB = {  # world/Lighting.luau terrainColors
    "Grass": (106, 168, 62), "LeafyGrass": (84, 150, 52), "Ground": (150, 116, 78), "Mud": (110, 86, 60),
    "Sand": (214, 190, 138), "Rock": (128, 124, 118), "Cobblestone": (150, 144, 132), "Water": (52, 128, 170),
}


def srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_blender(x, y, z):
    """Roblox (X, Y, Z) -> Blender (-X, Z, Y)."""
    return (-x, z, y)


def terrain_mesh(hf):
    nx, nz, step = hf["nx"], hf["nz"], hf["step"]
    verts, faces = [], []
    for j in range(nz):
        for i in range(nx):
            x, z = hf["x0"] + i * step, hf["z0"] + j * step
            verts.append(to_blender(x, hf["heights"][j * nx + i], z))
    for j in range(nz - 1):
        for i in range(nx - 1):
            a = j * nx + i
            faces.append((a, a + nx, a + nx + 1, a + 1))
    me = bpy.data.meshes.new("terrain")
    me.from_pydata(verts, [], faces)
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    for idx, m in enumerate(hf["materials"]):
        r, g, b = TERRAIN_RGB.get(m, TERRAIN_RGB["Grass"])
        attr.data[idx].color = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1)
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new("terrain", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("M_terrain")
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.95
    ob.data.materials.append(mat)
    return ob


def water_plane(hf, y):
    x0, z0 = hf["x0"], hf["z0"]
    x1, z1 = x0 + (hf["nx"] - 1) * hf["step"], z0 + (hf["nz"] - 1) * hf["step"]
    me = bpy.data.meshes.new("water")
    me.from_pydata([to_blender(x0, y, z0), to_blender(x1, y, z0), to_blender(x1, y, z1), to_blender(x0, y, z1)],
                   [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("water", me)
    bpy.context.scene.collection.objects.link(ob)
    mat = bpy.data.materials.new("M_water")
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    r, g, b = (46, 120, 168)
    bsdf.inputs["Base Color"].default_value = (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), 1)
    bsdf.inputs["Roughness"].default_value = 0.08
    ob.data.materials.append(mat)
    return ob


def add_haze(mat, colour=(0.66, 0.78, 0.93), start=350.0, end=2400.0, amount=0.35):
    nt = mat.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)
    if not out.inputs["Surface"].links:
        return
    src = out.inputs["Surface"].links[0].from_socket
    cam = nt.nodes.new("ShaderNodeCameraData")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = start
    mr.inputs["From Max"].default_value = end
    mr.inputs["To Max"].default_value = amount
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*colour, 1)
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(cam.outputs["View Distance"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(src, mix.inputs[1])
    nt.links.new(em.outputs["Emission"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])


def cf_matrix(c):
    return kitparts.cframe_matrix(c)


def views(data):
    """Camera views in Roblox coordinates: (location, target, vertical fov deg, orthographic scale)."""
    crimson = data["plots"]["crimson"]["keep"]
    kx, kz = crimson[0], crimson[2]
    obj = data["objective"]
    ox, oz = obj[0], obj[2]
    # crimson plot faces the valley centre; look at it from the valley side, elevated
    cx, cz = 40.0, 0.0
    dx, dz = cx - kx, cz - kz
    n = math.hypot(dx, dz)
    dx, dz = dx / n, dz / n
    return {
        "top": ((20, 1500, 20), (20, 0, 20.01), None, 1420),
        "valley": ((120, 380, 980), (0, 0, -60), 46, None),
        "crimson": ((kx + dx * 170 + dz * 60, 95, kz + dz * 170 - dx * 60), (kx, 8, kz), 50, None),
        "heartland": ((ox - 150, 70, oz + 140), (ox, 12, oz), 55, None),
        "street": ((kx + dx * 70 + dz * 12, 14, kz + dz * 70 - dx * 12), (kx, 12, kz), 70, None),
    }


# RulerCameraController overview: pitch 38 deg at minZoom 40 up to 65 at maxZoom 220 (Def.pitchFor); the field of view is one value
CAMERAS = {  # name: (zoom studs, vertical FOV degrees)
    "default": (70.0, 55.0),   # the new start view (FORGE-00, 2026-10-19): pitch 42.5
    "far": (220.0, 55.0),      # fully zoomed out
    "legacy": (120.0, 70.0),   # the B22 build's start view: pitch 50
}
KINGDOMS = ("crimson", "azure", "emerald", "gold")


def ruler_pitch(zoom):
    return 38.0 + (65.0 - 38.0) * (zoom - 40.0) / (220.0 - 40.0)


def ruler_view(data, kingdom, zoom, yaw_deg=0.0):
    """The ruler's overview camera: focus = the plot spawn, `zoom` studs away, yaw 0 (toward -Z) -> (location, focus)."""
    sp = data["plots"][kingdom]["spawn"]
    fx, fy, fz = sp[0], sp[1], sp[2]
    yaw, pitch = math.radians(yaw_deg), math.radians(ruler_pitch(zoom))
    fwd = (-math.sin(yaw), -math.cos(yaw))
    loc = (fx - fwd[0] * zoom * math.cos(pitch), fy + zoom * math.sin(pitch), fz - fwd[1] * zoom * math.cos(pitch))
    return loc, (fx, fy, fz)


def default_views(data):
    out = {}
    for k in KINGDOMS:
        for name, (zoom, fov) in CAMERAS.items():
            loc, tgt = ruler_view(data, k, zoom)
            out[f"{name}_{k}"] = (loc, tgt, fov, None, (1600, 900))
        zoom, fov = CAMERAS["default"]
        loc, tgt = ruler_view(data, k, zoom)
        out[f"default_phone_{k}"] = (loc, tgt, fov, None, (750, 311))
    return out


# ------------------------------------------------------------------ the world/Lighting.luau preset -> Blender


def luma(rgb):
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def lighting_params(preset):
    """Sun, sky fill, haze and grade from the dumped world/Lighting preset (see the module docstring: an approximation)."""
    lt, at, cc = preset["lighting"], preset["atmosphere"], preset["colorCorrection"]
    lat, hour = math.radians(lt.get("GeographicLatitude", 38)), lt.get("ClockTime", 12.0)
    h = math.radians((hour - 12.0) * 15.0)
    elevation = math.degrees(math.asin(max(0.05, math.cos(lat) * math.cos(h))))
    azimuth = -50.0 + (hour - 10.6) * 15.0  # 10.6 is the look the earlier previews were set up with
    sun = tuple(c / 255.0 for c in lt["ColorShift_Top"])
    strength = 4.6 * lt["Brightness"] / 2.6
    amb = tuple(c / 255.0 for c in lt["OutdoorAmbient"])
    ref = luma((150 / 255.0, 146 / 255.0, 158 / 255.0))
    fill_strength = 0.7 * luma(amb) / ref
    peak = max(amb)
    fill = tuple(c / peak for c in amb)
    fog = tuple(c / 255.0 for c in at["Color"])
    density, haze = at["Density"], at["Haze"]
    return {
        "elevation": elevation, "azimuth": azimuth, "sun": sun, "strength": strength, "fill": fill,
        "fill_strength": fill_strength, "fog": fog,
        "fog_start": 350.0 * 0.28 / max(density, 0.02), "fog_end": 2400.0 * 0.28 / max(density, 0.02),
        "fog_amount": min(0.9, 0.35 * (density / 0.28) * (0.6 + 0.4 * haze / 1.4)),
        "exposure": lt.get("ExposureCompensation", 0.0),
        "grade": {"brightness": cc["Brightness"], "contrast": cc["Contrast"], "saturation": cc["Saturation"],
                  "tint": tuple(c / 255.0 for c in cc["TintColor"])},
    }


def grade(img, g):
    """ColorCorrectionEffect on the finished render: brightness, contrast, saturation, tint (PIL; approximate)."""
    from PIL import ImageEnhance

    im = img.convert("RGB")
    im = ImageEnhance.Brightness(im).enhance(1.0 + g["brightness"])
    im = ImageEnhance.Contrast(im).enhance(1.0 + g["contrast"])
    im = ImageEnhance.Color(im).enhance(1.0 + g["saturation"])
    tint = g["tint"]
    r, gg, b = im.split()
    r, gg, b = (c.point(lambda v, t=t: min(255, int(v * t))) for c, t in zip((r, gg, b), tint))
    from PIL import Image

    return Image.merge("RGB", (r, gg, b))


def main(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", required=True)
    ap.add_argument("--views", default="top,valley,crimson,heartland,street")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--tag", default="")
    ap.add_argument("--out-dir", default="")
    ap.add_argument("--samples", type=int, default=0)
    args = ap.parse_args(argv)
    data = json.loads(Path(args.json).read_text())
    names = [v for v in args.views.split(",") if v]
    preset = lighting_params(data["lighting"]) if any(n.split("_")[0] in CAMERAS for n in names) and "lighting" in data else None

    rig.reset_scene()
    kitparts.reset_cache()
    sc = bpy.context.scene
    w, h = (800, 450) if args.quick else (1600, 900)
    rig.setup_render(sc, w, h, args.samples or (16 if args.quick else 48))
    sc.cycles.use_denoising = True
    if preset:
        rig.setup_world(sc, sky_top=(0.16, 0.42, 0.88), sky_horizon=preset["fog"], fill=preset["fill"],
                        fill_strength=preset["fill_strength"])
        rig.add_sun(sc, elevation_deg=preset["elevation"], azimuth_deg=preset["azimuth"], strength=preset["strength"],
                    color=preset["sun"])
        sc.view_settings.exposure = preset["exposure"]
        print(f"[world] lighting from the preset: sun {preset['elevation']:.1f} deg up, azimuth {preset['azimuth']:.0f}, "
              f"strength {preset['strength']:.2f}, fill {preset['fill_strength']:.2f}, fog {preset['fog_amount']:.2f} "
              f"from {preset['fog_start']:.0f} to {preset['fog_end']:.0f}", flush=True)
    else:
        rig.setup_world(sc, sky_top=(0.16, 0.42, 0.88), sky_horizon=(0.70, 0.82, 0.95), fill_strength=0.7)
        rig.add_sun(sc, elevation_deg=40, azimuth_deg=-50, strength=4.6)
    hf = data["heightfield"]
    terrain_mesh(hf)
    water_plane(hf, data["waterY"])
    col = sc.collection
    n_objs = 0
    for p in data["placements"]:
        m = cf_matrix(p["cframe"])
        s = p.get("scale")
        if s and s != 1:
            # a placement's size against the asset's own, about the model origin (WorldService scales every part's size and its
            # offset from the pivot, rotations stay): the 4x4 scale goes before the placement's own frame
            m = m @ Matrix.Diagonal((s, s, s, 1))
        objs = kitparts.build_model(data["assets"][p["assetId"]], col, transform=m)
        n_objs += len(objs)
    for m in bpy.data.materials:
        if m.node_tree and (m.name.startswith("kit_") or m.name in ("M_terrain", "M_water")):
            if preset:
                add_haze(m, colour=preset["fog"], start=preset["fog_start"], end=preset["fog_end"], amount=preset["fog_amount"])
            else:
                add_haze(m)
    print(f"[world] {len(data['placements'])} placements, {n_objs} part objects", flush=True)

    cam = rig.add_camera(sc, 50)
    out_dir = HERE / "renders" / "world"
    out_dir.mkdir(parents=True, exist_ok=True)
    jpg_dir = Path(args.out_dir) if args.out_dir else HERE / "previews"
    suffix = f"_{args.tag}" if args.tag else ""
    all_views = {**views(data), **default_views(data)}
    for name in names:
        view = all_views[name]
        loc, tgt, fov, ortho = view[:4]
        cam.location = Vector(to_blender(*loc))
        if ortho:
            cam.data.type = "ORTHO"
            cam.data.ortho_scale = ortho
            cam.rotation_euler = (0, 0, 0)
            sc.render.resolution_x, sc.render.resolution_y = (700, 700) if args.quick else (1300, 1300)
        else:
            cam.data.type = "PERSP"
            cam.data.sensor_fit = "VERTICAL"
            cam.data.angle_y = math.radians(fov)
            rig.aim(cam, Vector(to_blender(*tgt)))
            if len(view) > 4:
                sc.render.resolution_x, sc.render.resolution_y = view[4]
            else:
                sc.render.resolution_x, sc.render.resolution_y = w, h
        path = out_dir / f"world_{name}{suffix}.png"
        rig.render(sc, path)
        if contact.available():
            from PIL import Image

            img = Image.open(path)
            if preset:
                img = grade(img, preset["grade"])
            res = contact.save_jpeg_under(img, jpg_dir / f"world_{name}{suffix}.jpg")
            print(f"[world] {name}: {res[0]} {res[1]} bytes", flush=True)


if __name__ == "__main__":
    main(sys.argv)
