"""Render the AI Kingdoms world preview from the Lune world dump (FL-0055): a top-down map and oblique
views, so the layout, terrain, props and starting buildings can be reviewed before Studio (D-019).

  FORGE_WORLD_DUMP=/tmp/world.json lune run roblox/tests/harness/run.luau \
      --project games/game-001/default.project.json --specs games/game-001/tests/world WorldDump
  ~/forge-bpy/bin/python blender/scripts/render_world.py --json /tmp/world.json [--views top,valley] [--quick]

Writes blender/previews/world_<view>.jpg (<= 250 KB). Terrain colours match world/Lighting.luau
terrainColors; Roblox Terrain smoothing/textures and Lighting (Future, Atmosphere) are approximated.
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


def main(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", required=True)
    ap.add_argument("--views", default="top,valley,crimson,heartland,street")
    ap.add_argument("--quick", action="store_true")
    args = ap.parse_args(argv)
    data = json.loads(Path(args.json).read_text())

    rig.reset_scene()
    kitparts.reset_cache()
    sc = bpy.context.scene
    w, h = (800, 450) if args.quick else (1600, 900)
    rig.setup_render(sc, w, h, 16 if args.quick else 48)
    sc.cycles.use_denoising = True
    rig.setup_world(sc, sky_top=(0.16, 0.42, 0.88), sky_horizon=(0.70, 0.82, 0.95), fill_strength=0.7)
    rig.add_sun(sc, elevation_deg=40, azimuth_deg=-50, strength=4.6)
    hf = data["heightfield"]
    terrain_mesh(hf)
    water_plane(hf, data["waterY"])
    col = sc.collection
    n_objs = 0
    for p in data["placements"]:
        objs = kitparts.build_model(data["assets"][p["assetId"]], col, transform=cf_matrix(p["cframe"]))
        n_objs += len(objs)
    for m in bpy.data.materials:
        if m.node_tree and (m.name.startswith("kit_") or m.name in ("M_terrain", "M_water")):
            add_haze(m)
    print(f"[world] {len(data['placements'])} placements, {n_objs} part objects", flush=True)

    cam = rig.add_camera(sc, 50)
    out_dir = HERE / "renders" / "world"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in [v for v in args.views.split(",") if v]:
        loc, tgt, fov, ortho = views(data)[name]
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
            sc.render.resolution_x, sc.render.resolution_y = w, h
        path = out_dir / f"world_{name}.png"
        rig.render(sc, path)
        if contact.available():
            from PIL import Image

            res = contact.save_jpeg_under(Image.open(path), HERE / "previews" / f"world_{name}.jpg")
            print(f"[world] {name}: previews/world_{name}.jpg {res[1]} bytes", flush=True)


if __name__ == "__main__":
    main(sys.argv)
