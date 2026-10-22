"""True-size crops of the 23 citizens of one kingdom (visual upgrade pass 1, stream C: citizen readability).

A default-camera render shows only the citizens that happen to stand inside the frame (at the start view, zoom 70, about 130 x 73 studs
around the plot spawn: 15 of the 23 crimson ones). To judge all 23 at the size a player sees them, this script builds the same scene as
render_world.py (terrain, every placement, the world/Lighting.luau preset, haze and colour grade) and, for each citizen, puts the same
camera (same zoom, pitch, field of view, resolution: so the same studs per pixel) on that citizen and renders only a small window around
the figure (Cycles border render), at the resolution of the chosen device. The tiles go on one sheet, labelled by job, at 1:1
(--scale 1 is what the player sees; --scale 3 or 4 adds a nearest-neighbour enlargement for the eye, nothing re-rendered).

  nice -n 5 ~/forge-bpy/bin/python blender/scripts/citizen_crops.py --json world.json --kingdom crimson \
      --runs default@1920x1080,default@750x311,far@1920x1080,far@750x311 --tag after --out-dir DIR [--scale 1] [--tile 128]

  --runs  <view>@<W>x<H>, comma separated; the scene is built once. Views: default (zoom 70, FOV 55, pitch 42.5: the start view),
          far (zoom 220, FOV 55, pitch 65), legacy (zoom 120, FOV 70, pitch 50). Sizes: 1920x1080 (desktop 1080p), 750x311 (phone)

Writes DIR/citizens_<view>_<WxH>_<kingdom>_<tag>.jpg (<= 250 KB) per run. The citizen is centred on the
body (2.75 studs up), so its crop is not the default frame's own perspective at that spot; the scale is the one at the screen centre.
"""

import argparse
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import render_world as rw  # noqa: E402
from lib import contact, kitparts, rig  # noqa: E402

JOB_ORDER = ["farmer", "woodcutter", "miner", "hauler", "builder", "idle"]


def build_scene(data, samples):
    preset = rw.lighting_params(data["lighting"])
    rig.reset_scene()
    kitparts.reset_cache()
    sc = bpy.context.scene
    rig.setup_render(sc, 1920, 1080, samples)
    sc.cycles.use_denoising = True
    rig.setup_world(sc, sky_top=(0.16, 0.42, 0.88), sky_horizon=preset["fog"], fill=preset["fill"],
                    fill_strength=preset["fill_strength"])
    rig.add_sun(sc, elevation_deg=preset["elevation"], azimuth_deg=preset["azimuth"], strength=preset["strength"],
                color=preset["sun"])
    sc.view_settings.exposure = preset["exposure"]
    hf = data["heightfield"]
    rw.terrain_mesh(hf)
    rw.water_plane(hf, data["waterY"])
    for p in data["placements"]:
        kitparts.build_model(data["assets"][p["assetId"]], sc.collection, transform=rw.cf_matrix(p["cframe"]))
    for m in bpy.data.materials:
        if m.node_tree and (m.name.startswith("kit_") or m.name in ("M_terrain", "M_water")):
            rw.add_haze(m, colour=preset["fog"], start=preset["fog_start"], end=preset["fog_end"], amount=preset["fog_amount"])
    return sc, preset


def citizens(data, kingdom):
    out = []
    for p in data["placements"]:
        if p.get("feature") == "citizen" and p["assetId"].endswith("_" + kingdom):
            job = p["assetId"][len("citizen_"):-len("_" + kingdom)]
            out.append((job, p))
    out.sort(key=lambda jp: JOB_ORDER.index(jp[0]) if jp[0] in JOB_ORDER else 99)
    return out


def sheet_for(sc, cam, data, preset, view, W, H, args, rows_out):
    from PIL import Image, ImageDraw, ImageFont

    sc.render.resolution_x, sc.render.resolution_y = W, H
    zoom, fov = rw.CAMERAS[view]
    pitch = math.radians(rw.ruler_pitch(zoom))
    cam.data.angle_y = math.radians(fov)
    tile = args.tile
    grab = tile + 32  # rendered window; the denoiser smears its edge, the sheet keeps the middle `tile`
    sc.render.border_min_x = (W / 2 - grab / 2) / W
    sc.render.border_max_x = (W / 2 + grab / 2) / W
    sc.render.border_min_y = (H / 2 - grab / 2) / H
    sc.render.border_max_y = (H / 2 + grab / 2) / H
    only = {j for j in args.only.split(",") if j}
    tiles = []
    tmp = HERE / "renders" / "world"
    tmp.mkdir(parents=True, exist_ok=True)
    for i, (job, p) in enumerate(citizens(data, args.kingdom)):
        if only and job not in only:
            continue
        c = p["cframe"]
        fx, fy, fz = c[0], c[1] + 2.75, c[2]  # the body's centre
        loc = (fx, fy + zoom * math.sin(pitch), fz + zoom * math.cos(pitch))  # yaw 0: the camera stands at +Z, looking toward -Z
        cam.location = Vector(rw.to_blender(*loc))
        rig.aim(cam, Vector(rw.to_blender(fx, fy, fz)))
        path = tmp / f"crop_{view}_{W}_{i:02d}.png"
        rig.render(sc, path)
        img = rw.grade(Image.open(path).convert("RGB"), preset["grade"])
        w, h = img.size
        left, top = (w - tile) // 2, (h - tile) // 2
        tiles.append((job, img.crop((left, top, left + tile, top + tile))))
        print(f"[crops] {view} {W}x{H} {i:02d} {job}", flush=True)
    for k in sorted({max(1, int(v)) for v in str(args.scale).split(",")}):
        compose(tiles, args, view, W, H, zoom, fov, k)


def compose(tiles, args, view, W, H, zoom, fov, k):
    from PIL import Image, ImageDraw, ImageFont

    tile = args.tile
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    pad, head, lab = 6, 28, 16
    cw = tile * k
    sheet = Image.new("RGB", (cols * (cw + pad) + pad, head + rows * (cw + lab + pad) + pad), (34, 37, 42))
    d = ImageDraw.Draw(sheet)
    try:
        font, big = ImageFont.load_default(size=12), ImageFont.load_default(size=15)
    except TypeError:
        font = big = ImageFont.load_default()
    d.text((pad, 6), f"{args.kingdom} citizens ({args.tag or 'render'}), {view} camera, zoom {zoom:.0f} FOV {fov:.0f} pitch "
                     f"{rw.ruler_pitch(zoom):.1f}, drawn for {W} x {H}, tiles {tile} px "
                     + ("at 1:1" if k == 1 else f"shown x{k} (nearest)"), fill=(245, 236, 210), font=big)
    for n, (job, im) in enumerate(tiles):
        if k > 1:
            im = im.resize((cw, cw), Image.NEAREST)
        ox, oy = pad + (n % cols) * (cw + pad), head + (n // cols) * (cw + lab + pad)
        sheet.paste(im, (ox, oy))
        d.text((ox + 1, oy + cw + 2), job, fill=(200, 204, 212), font=font)
    name = f"citizens_{view}_{W}x{H}_{args.kingdom}" + (f"_{args.tag}" if args.tag else "") + (f"_x{k}" if k > 1 else "")
    res = contact.save_jpeg_under(sheet, Path(args.out_dir) / f"{name}.jpg")
    print(f"[crops] wrote {res[0]} {res[1]} bytes {res[3]}", flush=True)


def main(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", required=True)
    ap.add_argument("--kingdom", default="crimson")
    ap.add_argument("--runs", default="default@1920x1080,default@750x311,far@1920x1080,far@750x311",
                    help="comma list of <view>@<W>x<H>; the scene is built once")
    ap.add_argument("--tag", default="")
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--tile", type=int, default=128)
    ap.add_argument("--scale", default="1,3", help="comma list of nearest-neighbour enlargements to write (1 = true size)")
    ap.add_argument("--samples", type=int, default=24)
    ap.add_argument("--only", default="", help="comma list of jobs to render (default all)")
    args = ap.parse_args(argv)
    Path(args.out_dir).mkdir(parents=True, exist_ok=True)
    data = json.loads(Path(args.json).read_text())
    preset = rw.lighting_params(data["lighting"])
    sc, _ = build_scene(data, args.samples)
    cam = rig.add_camera(sc, 50)
    cam.data.type = "PERSP"
    cam.data.sensor_fit = "VERTICAL"
    sc.render.use_border = True
    sc.render.use_crop_to_border = True
    for run in args.runs.split(","):
        view, res = run.split("@")
        W, H = (int(v) for v in res.lower().split("x"))
        sheet_for(sc, cam, data, preset, view, W, H, args, None)


if __name__ == "__main__":
    main(sys.argv)
